// Capacify Cloud Functions (2nd gen).
//
// Cost posture: europe-west3 (EU data residency), maxInstances capped so a
// traffic spike can't runaway-bill, and no minInstances (zero idle compute).
// At pre-launch volume this sits inside the free tier.
//
// Jobs:
//   • verifyMyCompany     — H3: live EU VIES VAT check, kills the manual verify bottleneck
//   • uploadCompanyLogo   — server-side logo upload, works around a FlutterFire Web putData() metadata bug
//   • sendVerificationEmail — custom-branded verify-email link, replaces Firebase's default template
//   • purgeUserData       — H8/M1: recursive GDPR erasure of chats the client can't hard-delete
//   • deleteChat          — participant-initiated delete of one chat, once its post is closed/cancelled
//   • notifyOnGrant       — C1: email the poster the moment a request reveals them (transactional)
//   • notifyOnNewCapacity — retention: email owners of matching saved searches on a new post
//   • weeklyDigest        — retention: Monday "your market this week" overview
//   • emailUnsubscribe    — RFC 8058 one-click opt-out target for the two retention emails
//   • onNewMessage        — #9: notification + push + debounced email on a new chat message
//   • onVerificationSubmitted / onCapacityFlagged / onCompanyFlagged / onRatingWrite
//                         — #9: notification + push to every admin the moment something needs review
//
// Email posture (GDPR): notifyOnGrant and onNewMessage are TRANSACTIONAL (a
// direct response to the recipient's own listing/conversation) and only need
// SMTP configured — onNewMessage is additionally debounced per (chat,
// recipient) so a burst of messages can't spam an inbox, and skipped entirely
// if the recipient has users/{uid}.notifyOnNewMessage == false. The two
// retention emails are ENGAGEMENT — they additionally require the recipient to
// have opted in (companies/{id}.emailOptIn == true) and are the only two that
// carry List-Unsubscribe headers (see bulkMailFields / emailUnsubscribe);
// transactional mail isn't a subscription and must not be opt-out-able.
// Every email/push path is a no-op until SMTP_URL *and* MAIL_FROM are set (see
// mailReady) / an FCM token exists, so the app is unaffected until then.
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const moderation = require('./moderation');

// storageBucket MUST be set explicitly. This project's only bucket is the
// new-format `capacify-mvp.firebasestorage.app`; there is NO legacy
// `capacify-mvp.appspot.com` bucket (it 404s). With no storageBucket here,
// admin.storage().bucket() falls back to the legacy `<projectId>.appspot.com`
// name, so every uploadCompanyLogo .save() wrote to a bucket that doesn't
// exist and failed — the source of the logo-upload error. Naming the real
// bucket makes both the write and the returned download URL correct.
admin.initializeApp({ storageBucket: 'capacify-mvp.firebasestorage.app' });
// 5 is the SAFE DEFAULT for anything with real per-call cost (an external API
// call, an email send, an admin/account-lifecycle action) — deliberately tight
// so a traffic spike can't runaway-bill. It was previously the ceiling for
// EVERY function, including the cheap, high-frequency internal triggers that
// fire on every capacity/company/contact_request/rating write — five
// concurrent writes to any one of those collections would exhaust that
// specific function's own instances and start queuing/retrying, a
// self-inflicted bottleneck with no attacker required. Those specific
// triggers now override this default with their own `maxInstances: 20` (see
// each declaration below) — everything else still inherits this 5.
setGlobalOptions({ region: 'europe-west3', maxInstances: 5 });

const db = () => admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// H3 — Live VAT verification via the EU VIES REST API (no key, free, but blocked
// by CORS from a browser, which is exactly why it must run server-side). The
// caller verifies THEIR OWN company: we read their company doc, check its VAT
// against VIES, and on a valid result stamp the company verified + store the
// registered name for the founder to spot-check. Invalid/unavailable → left for
// manual review (never auto-rejected — VIES has downtime).
// ─────────────────────────────────────────────────────────────────────────────
exports.verifyMyCompany = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const uid = req.auth.uid;

  const companyRef = db().collection('companies').doc(uid);
  const snap = await companyRef.get();
  if (!snap.exists) throw new HttpsError('not-found', 'No company profile.');

  const raw = String(snap.data().vatNumber || '').toUpperCase().replace(/\s/g, '');
  const m = raw.match(/^([A-Z]{2})(.+)$/);
  if (!m) throw new HttpsError('failed-precondition', 'No valid VAT number on file.');
  const [, countryCode, vatNumber] = m;

  let result;
  try {
    const res = await fetch(
      'https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ countryCode, vatNumber }),
      }
    );
    result = await res.json();
  } catch (e) {
    throw new HttpsError('unavailable', 'VIES is temporarily unavailable. Try again later.');
  }

  const valid = result && result.valid === true;
  const viesName = (result && result.name) || '';

  // FLAG, don't auto-verify. A valid VAT only proves the number is real — not
  // that it belongs to this company. So we record the VIES result and route the
  // company into the founder's approval (Freigabe) queue with the registered
  // name attached, rather than granting the verified badge automatically.
  if (valid) {
    const cur = snap.data().verificationStatus;
    await companyRef.update({
      vatValid: true,
      vatVerifiedName: viesName,
      // H4 fix: the raw VAT number isn't stored pre-normalized, so the
      // duplicate-VAT check in enforceCompanyIntegrity used to pull every
      // vatValid:true company and normalize+compare each one in memory — an
      // O(n) scan on every verified profile edit. Stamping the already-
      // normalized value here lets that check run as a single equality query
      // instead. `raw` was normalized (uppercase, no spaces) at the top of
      // this function from the same vatNumber this VIES check just validated.
      vatNumberNormalized: raw,
      vatVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Only move into the review queue if not already verified.
      ...(cur === 'verified' ? {} : { verificationStatus: 'pending' }),
    });
  } else {
    await companyRef.update({ vatValid: false });
  }

  return { valid, name: viesName };
});

// ─────────────────────────────────────────────────────────────────────────────
// Company logo upload. NOT done as a direct client write to Storage — that hit
// a confirmed FlutterFire Web bug (flutterfire#12607): Reference.putData() on
// Flutter Web doesn't reliably transmit SettableMetadata (contentType) with
// the upload, so a storage.rules content-type check was rejecting every web
// upload outright. Dropping that check didn't fix it either — evidence some
// OTHER piece of client-side upload metadata (most likely request.resource.size)
// is just as unreliable from Flutter Web, not only contentType. Rather than
// keep guessing which field to stop checking, the actual bytes are handed to
// this function and written via the Admin SDK, which bypasses Storage rules
// entirely — no client metadata transmission involved at any point.
// storage.rules now denies ALL client writes to company_logos/**; only this
// function may write there. Fixed path (one logo per company; a re-upload
// overwrites, no orphaned files) + a fresh download token each time (a
// same-path overwrite needs a new token, or the OLD cached download URL
// would keep resolving to whatever's newest at that path anyway, but a fresh
// token also invalidates any previously-shared direct link).
// ─────────────────────────────────────────────────────────────────────────────
// Rebuilt as a plain onRequest HTTP function (was onCall) — the callable
// wrapper's client SDK tries to attach an App Check token to every request
// before it goes out, and a broken/unregistered App Check configuration made
// that attachment step itself fail, taking the whole upload down with it even
// though App Check enforcement was never turned on for this function. A raw
// POST + manual ID-token verification has no App Check involvement at all, so
// it can't be taken out by that same failure mode. Auth is now verified by
// hand via admin.auth().verifyIdToken() instead of the req.auth the onCall
// wrapper used to provide.
// Authoritative decoded-size cap for a logo (1 MB). The client resizes to
// max 512px first, so a real logo lands far below this.
const LOGO_MAX_BYTES = 1024 * 1024;

// Identify the image type from the BYTES (magic number), not the client's
// declared content-type. Only genuine raster formats pass — SVG is
// deliberately excluded: an image/svg+xml is active content, and since logos
// are world-readable and served inline off firebasestorage.googleapis.com via
// a download token, a script-bearing SVG (or any payload mislabeled as an
// image) would be a stored-XSS / phishing vector hosted under the project.
// Returns the canonical content-type to store, or null if it isn't a
// supported raster image.
function sniffRasterImageType(buf) {
  if (buf.length >= 8 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e &&
      buf[3] === 0x47 && buf[4] === 0x0d && buf[5] === 0x0a && buf[6] === 0x1a &&
      buf[7] === 0x0a) return 'image/png';
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
    return 'image/jpeg';
  }
  if (buf.length >= 6 && buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46 &&
      buf[3] === 0x38 && (buf[4] === 0x37 || buf[4] === 0x39) && buf[5] === 0x61) {
    return 'image/gif';
  }
  if (buf.length >= 12 && buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 &&
      buf[3] === 0x46 && buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 &&
      buf[11] === 0x50) return 'image/webp';
  return null;
}

// Browser origins allowed to script against this endpoint. Auth is a Bearer ID
// token (never an ambient cookie), so this is NOT a CSRF control — a foreign
// site can't obtain a capacify user's token — it's hygiene that stops arbitrary
// origins reading responses. Non-browser callers ignore CORS entirely.
const LOGO_ALLOWED_ORIGINS = new Set([
  'https://capacify.de',
  'https://www.capacify.de',
  'https://capacify-mvp.web.app',
  'https://capacify-mvp.firebaseapp.com',
]);
function logoAllowedOrigin(origin) {
  if (!origin) return null;
  if (LOGO_ALLOWED_ORIGINS.has(origin)) return origin;
  // Local dev: `flutter run` serves on an arbitrary localhost port.
  if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return origin;
  return null;
}

exports.uploadCompanyLogo = onRequest(async (req, res) => {
  const allowedOrigin = logoAllowedOrigin(req.get('Origin'));
  if (allowedOrigin) {
    res.set('Access-Control-Allow-Origin', allowedOrigin);
    res.set('Vary', 'Origin');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Max-Age', '3600');
  }
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed.' });
    return;
  }

  const authHeader = req.get('Authorization') || '';
  const bearerMatch = authHeader.match(/^Bearer (.+)$/);
  if (!bearerMatch) {
    res.status(401).json({ error: 'Sign in required.' });
    return;
  }
  let uid;
  try {
    uid = (await admin.auth().verifyIdToken(bearerMatch[1])).uid;
  } catch (e) {
    res.status(401).json({ error: 'Invalid or expired session.' });
    return;
  }

  const { base64Data } = req.body || {};
  if (!base64Data || typeof base64Data !== 'string') {
    res.status(400).json({ error: 'Missing image data.' });
    return;
  }
  // Reject oversize payloads BEFORE allocating the decoded buffer: base64 is
  // ~4/3 of the binary length, so anything past this can't be a <1 MB image and
  // we refuse to spend memory decoding it. (Cloud Run caps the request body too,
  // but this bounds our own allocation regardless of that limit.)
  if (base64Data.length > Math.ceil((LOGO_MAX_BYTES * 4) / 3) + 4) {
    res.status(400).json({ error: 'File must be a non-empty image under 1 MB.' });
    return;
  }

  let buffer;
  try {
    buffer = Buffer.from(base64Data, 'base64');
  } catch (e) {
    res.status(400).json({ error: 'Could not read the image data.' });
    return;
  }
  // The authoritative cap — this Admin SDK write is the only path that can
  // actually reach Storage, so this is what really bounds per-logo cost, not
  // the client's own pre-check. The client already resizes to max 512px
  // before it gets here, so a real photo should land well under this.
  if (buffer.length === 0 || buffer.length >= LOGO_MAX_BYTES) {
    res.status(400).json({ error: 'File must be a non-empty image under 1 MB.' });
    return;
  }

  // Trust the bytes, not the caller: only real PNG/JPEG/GIF/WEBP data passes,
  // and the SNIFFED type — never a client-supplied string — is what gets stored
  // and served. This is what actually blocks an SVG-with-script or a payload
  // mislabeled as an image from being hosted as one.
  const imageType = sniffRasterImageType(buffer);
  if (!imageType) {
    res.status(400).json({ error: 'Nur PNG-, JPG-, WEBP- oder GIF-Bilder werden unterstützt.' });
    return;
  }

  const path = `company_logos/${uid}/logo`;
  const token = crypto.randomUUID();
  const bucket = admin.storage().bucket();

  try {
    await bucket.file(path).save(buffer, {
      contentType: imageType,
      metadata: { metadata: { firebaseStorageDownloadTokens: token } },
    });
  } catch (e) {
    console.error('uploadCompanyLogo: save failed', e);
    res.status(500).json({ error: 'Could not upload the logo.' });
    return;
  }

  const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
  res.status(200).json({ url });
});

// ─────────────────────────────────────────────────────────────────────────────
// H8 / M1 — Recursive GDPR erasure. Chat threads + their messages subcollection
// are immutable to clients by design (firestore.rules), so a full "delete my
// data" needs the Admin SDK. The client calls this WHILE still authed (before
// deleting the Auth user); we remove every chat the user participates in, along
// with the nested messages, via recursiveDelete.
// ─────────────────────────────────────────────────────────────────────────────
exports.purgeUserData = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const uid = req.auth.uid;

  const chats = await db().collection('chats').where('participants', 'array-contains', uid).get();
  let deleted = 0;
  for (const doc of chats.docs) {
    await db().recursiveDelete(doc.ref);
    deleted++;
  }
  return { deletedChats: deleted };
});

// ─────────────────────────────────────────────────────────────────────────────
// Delete a single chat once its underlying post is done (closed/cancelled) —
// same recursiveDelete need as purgeUserData above (chats/{id} carries a
// messages subcollection that clients can never delete, by design), just
// scoped to one thread instead of the whole account. Only a participant may
// call this, and only once the post it's about has actually been closed or
// cancelled — while a deal is still active/in-progress the chat stays, since
// either side might still need it.
// ─────────────────────────────────────────────────────────────────────────────
exports.deleteChat = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const chatId = req.data && req.data.chatId;
  if (!chatId || typeof chatId !== 'string') {
    throw new HttpsError('invalid-argument', 'chatId is required.');
  }

  const chatRef = db().collection('chats').doc(chatId);
  const chatSnap = await chatRef.get();
  if (!chatSnap.exists) return { deleted: false };

  const chatData = chatSnap.data();
  const participants = chatData.participants || [];
  if (!participants.includes(req.auth.uid)) {
    throw new HttpsError('permission-denied', 'Not a participant of this chat.');
  }

  const postId = chatData.postId;
  const postSnap = postId ? await db().collection('capacities').doc(postId).get() : null;
  const status = postSnap && postSnap.exists ? postSnap.data().status : null;
  if (status !== 'closed' && status !== 'cancelled') {
    throw new HttpsError('failed-precondition', 'The post must be closed or cancelled first.');
  }

  await db().recursiveDelete(chatRef);
  return { deleted: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// C1 — Close the loop: when a contact request flips to 'granted' (a company
// spent a credit and the poster was just revealed), email the poster so they
// don't have to be logged in to discover the interest. Sending needs an SMTP
// credential (SMTP_URL secret); until that's set the function deploys and runs
// but skips the send, so the rest of the app is unaffected.
// ─────────────────────────────────────────────────────────────────────────────
const SMTP_URL = process.env.SMTP_URL || '';
// NO default sender, deliberately. This used to fall back to Resend's shared
// sandbox address (onboarding@resend.dev), which only ever delivers to the
// Resend account owner's own inbox. With SMTP_URL set but MAIL_FROM forgotten,
// the relay ACCEPTS every message and drops it — no bounce, no error, nothing
// in these logs — so a launched product would look like it was emailing users
// and reach none of them. An unset MAIL_FROM is now the same explicit
// "not configured yet" state as an unset SMTP_URL: see mailReady().
//
// Before launch MAIL_FROM must be an address on a domain verified with the
// relay (e.g. `Capacify <hallo@capacify.de>`), with SPF, DKIM and DMARC
// published for it — a From: domain without those is spam-foldered by Gmail
// and rejected outright by several German business mail hosts.
const MAIL_FROM = process.env.MAIL_FROM || '';
const APP_URL = process.env.APP_URL || 'https://capacify.de';

// ── One-click unsubscribe (RFC 8058) ────────────────────────────────────────
// Gmail and Yahoo's bulk-sender rules require a working one-click unsubscribe
// on marketing/engagement mail. A footer sentence pointing at the Settings
// screen does not satisfy it: the requirement is a List-Unsubscribe header the
// mail client itself can act on, which is what puts the native "Unsubscribe"
// button next to the sender name.
//
// UNSUB_SECRET signs the per-recipient link. Without it there is no way to
// tell a real link from a guessed one — company ids are readable from the
// public directory, so an unsigned endpoint would let anyone unsubscribe any
// company. Unset → the headers are omitted rather than sent unsigned, and the
// engagement sends log that they went out without them.
const UNSUB_SECRET = process.env.UNSUB_SECRET || '';
// Optional monitored mailbox for the mailto: form (some older clients only
// support that one). Only advertised when set — pointing at an address nobody
// reads is worse than omitting it, since the unsubscribe silently fails.
const UNSUB_MAILBOX = process.env.UNSUB_MAILBOX || '';
// Served from our own domain via the Hosting rewrite in firebase.json, so the
// unsubscribe link sits on the same domain as the From: address. Override with
// UNSUB_URL to point straight at the function instead.
const UNSUB_URL = process.env.UNSUB_URL || `${APP_URL}/e/abmelden`;

function unsubToken(companyId) {
  return crypto.createHmac('sha256', UNSUB_SECRET).update(`unsub:${companyId}`).digest('hex');
}

// The recipient's personal unsubscribe link, or null when unsigned.
function unsubLinkFor(companyId) {
  if (!UNSUB_SECRET || !companyId) return null;
  return `${UNSUB_URL}?c=${encodeURIComponent(companyId)}&t=${unsubToken(companyId)}`;
}

// Extra sendMail fields that mark a message as bulk and make it unsubscribable.
// Transactional mail (a reply to your own listing, a chat message, an address
// verification) deliberately does NOT get these — those aren't a subscription
// and shouldn't be opt-out-able.
function bulkMailFields(companyId) {
  const link = unsubLinkFor(companyId);
  if (!link) return {};
  const targets = [`<${link}>`];
  if (UNSUB_MAILBOX) targets.push(`<mailto:${UNSUB_MAILBOX}?subject=unsubscribe>`);
  return {
    headers: {
      'List-Unsubscribe': targets.join(', '),
      // Declares RFC 8058 support: the client may POST the link directly
      // instead of opening it, so unsubscribing takes one tap and never
      // leaves the inbox.
      'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
    },
  };
}

// Single gate for "can we actually deliver mail right now?". Every send path
// below runs through this instead of testing SMTP_URL alone.
function mailReady(where) {
  if (!SMTP_URL) {
    console.log(`${where}: no SMTP_URL configured — skipping email.`);
    return false;
  }
  if (!MAIL_FROM) {
    console.error(
      `${where}: SMTP_URL is set but MAIL_FROM is not. Refusing to send — ` +
      'a missing sender means the relay accepts the mail and silently drops ' +
      'it. Set MAIL_FROM to a verified sender on capacify.de.'
    );
    return false;
  }
  return true;
}

// Called by the engagement sends once they know they're about to send to
// someone. Bulk mail still goes out unsigned — an opted-in recipient shouldn't
// lose their alerts over a missing env var — but never quietly.
function warnIfUnsignedBulk(where) {
  if (UNSUB_SECRET) return;
  console.error(
    `${where}: UNSUB_SECRET is not set — sending WITHOUT List-Unsubscribe ` +
    'headers. Gmail and Yahoo require a working one-click unsubscribe on ' +
    'bulk mail; without it this mail is a spam-folder candidate.'
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// The unsubscribe endpoint the List-Unsubscribe header points at.
//
// Two callers, both handled here:
//   • POST — the mail client itself, doing RFC 8058 one-click. It sends
//     `List-Unsubscribe=One-Click` as the body and never shows the response,
//     so a bare 200 is the whole contract. It carries NO cookie or auth, which
//     is why the link is HMAC-signed: the signature is the only thing proving
//     this request came from a link we generated.
//   • GET — a human clicking the footer link, who gets a confirmation page.
//
// Unsubscribing clears companies/{id}.emailOptIn, which is the opt-in the two
// engagement emails are gated on. Transactional mail (someone replied to your
// listing, a chat message, address verification) is deliberately untouched —
// that isn't a subscription and silently dropping it would break the product.
// ─────────────────────────────────────────────────────────────────────────────
exports.emailUnsubscribe = onRequest(async (req, res) => {
  const page = (title, body) => `<!DOCTYPE html><html lang="de"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} — Capacify</title></head>
<body style="margin:0;background:#eef1f4;font:400 15px/1.6 Arial,Helvetica,sans-serif;color:#3f4652">
<div style="max-width:520px;margin:64px auto;padding:32px;background:#fff;border:1px solid #e6e9ee;border-radius:16px">
<div style="font:900 22px/1 Arial,Helvetica,sans-serif;color:#111;letter-spacing:-.5px;margin-bottom:20px">Capac<span style="color:${BRAND}">ify</span></div>
<h1 style="margin:0 0 12px;font:800 20px/1.35 Arial,Helvetica,sans-serif;color:#111">${title}</h1>
<p style="margin:0 0 18px">${body}</p>
<a href="${APP_URL}" style="display:inline-block;padding:12px 24px;border-radius:10px;background:${BRAND};color:#fff;font-weight:800;text-decoration:none">Zu Capacify</a>
</div></body></html>`;

  if (req.method !== 'GET' && req.method !== 'POST') {
    res.set('Allow', 'GET, POST');
    res.status(405).send('Method not allowed.');
    return;
  }

  const companyId = String((req.query && req.query.c) || '');
  const token = String((req.query && req.query.t) || '');

  // Any failure below answers identically, so this can't be used to probe
  // which company ids exist.
  const reject = () => {
    if (req.method === 'POST') { res.status(400).send('Invalid unsubscribe link.'); return; }
    res.status(400).send(page(
      'Link ungültig',
      'Dieser Abmelde-Link ist ungültig oder abgelaufen. Sie können Benachrichtigungen jederzeit direkt in den Einstellungen abstellen.'
    ));
  };

  if (!UNSUB_SECRET || !companyId || !token) return reject();
  // Firestore document ids: no slashes, no path traversal, bounded length.
  if (companyId.length > 128 || companyId.includes('/')) return reject();

  const expected = Buffer.from(unsubToken(companyId), 'utf8');
  const given = Buffer.from(token, 'utf8');
  if (expected.length !== given.length || !crypto.timingSafeEqual(expected, given)) return reject();

  try {
    const ref = db().collection('companies').doc(companyId);
    // update() rather than set(merge): a deleted company must not be
    // resurrected as a stub doc by an unsubscribe click. A missing doc means
    // there is nothing left subscribed, which is the outcome asked for.
    await ref.update({ emailOptIn: false });
    console.log('emailUnsubscribe: opted out', companyId, `(${req.method})`);
  } catch (e) {
    if (e && e.code === 5) {
      console.log('emailUnsubscribe: company no longer exists', companyId);
    } else {
      console.error('emailUnsubscribe: write failed', companyId, e);
      if (req.method === 'POST') { res.status(500).send('Could not process the unsubscribe.'); return; }
      res.status(500).send(page(
        'Das hat nicht geklappt',
        'Wir konnten Sie gerade nicht abmelden. Bitte versuchen Sie es später erneut oder stellen Sie die Benachrichtigungen in den Einstellungen ab.'
      ));
      return;
    }
  }

  if (req.method === 'POST') { res.status(200).send('Unsubscribed.'); return; }
  res.status(200).send(page(
    'Sie sind abgemeldet',
    'Sie erhalten keine Match-Benachrichtigungen und keinen Wochenüberblick mehr. ' +
    'E-Mails zu Ihren eigenen Anzeigen und Nachrichten bekommen Sie weiterhin — ' +
    'auch die können Sie in den Einstellungen abstellen.'
  ));
});

// Master email kill-switch. users/{uid}.notifyByEmail (default true when unset)
// is the global "send me no email" preference the Settings screen writes. EVERY
// notification-email path below honours it. The sole exception is
// sendVerificationEmail — email confirmation is essential account security, not
// a notification, so a user who opted out of email must still be able to verify.
// Fail-open: an unresolved/absent uid never suppresses, matching the existing
// "no-op until configured" posture of every other email path here.
async function emailAllowedForUser(uid) {
  if (!uid) return true;
  try {
    const snap = await db().collection('users').doc(uid).get();
    return !snap.exists || snap.data().notifyByEmail !== false;
  } catch (e) {
    console.error('emailAllowedForUser failed', e);
    return true;
  }
}

// A company's notification address. Contact data was moved OFF the
// world-readable companies document into the gated companyContacts sidecar
// (see firestore.rules) — the public doc is `read: if true` so anonymous
// visitors can browse the directory, which also meant an unauthenticated REST
// read returned every company's email, phone and address in one request.
//
// `companyData` is the already-fetched companies doc where the caller has one,
// used only as a FALLBACK for companies whose inline contact hasn't been moved
// yet. That fallback is what makes this safe to deploy in either order
// relative to the one-off migration; once the migration has run there is
// nothing left inline for it to find. Admin SDK reads bypass rules, so the
// gating above doesn't affect any of this.
async function companyNotifyEmail(companyId, companyData) {
  if (!companyId) return null;
  try {
    const snap = await db().doc(`companyContacts/${companyId}`).get();
    const email = snap.exists && snap.data().email;
    if (email) return email;
  } catch (e) {
    console.error('companyNotifyEmail lookup failed', companyId, e);
  }
  return (companyData && companyData.email) || null;
}

exports.notifyOnGrant = onDocumentWritten('contact_requests/{id}', async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;

  const becameGranted = after.status === 'granted' && (!before || before.status !== 'granted');
  if (!becameGranted) return;

  if (!mailReady('notifyOnGrant')) return;

  // The poster's contact email lives only in the locked sidecar.
  const owner = (await db().doc(`capacityOwners/${after.postId}`).get()).data();
  const to = owner && owner.contactEmail;
  if (!to) {
    console.log('notifyOnGrant: no poster email found for post', after.postId);
    return;
  }
  if (!(await emailAllowedForUser(owner.posterCompanyId))) {
    console.log('notifyOnGrant: poster opted out of email — skipping.');
    return;
  }

  // A visible/discreet post's request is created ALREADY granted (see
  // ContactRequestService.requestContact) — this fires on that creation too,
  // not just a poster's Accept. onNewContactRequest below fires in parallel
  // for the SAME event; its own urgent email is suppressed for an
  // auto-granted request specifically so a poster gets exactly one email,
  // not two, for one event — the urgency line lives here instead.
  const urgent = after.urgent === true;

  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    const mail = urgent
      ? renderEmail({
          accent: BRAND,
          emoji: '🔥',
          eyebrow: 'Dringende Anfrage',
          heading: 'Ein Unternehmen braucht Sie — schnell',
          paragraphs: [
            'Ein Unternehmen hat über Capacify Interesse an einer Ihrer Anzeigen freigeschaltet und als dringend markiert.',
            'Es wartet jetzt auf eine schnelle Rückmeldung — der beste Moment, um ins Geschäft zu kommen.',
          ],
          cta: { label: 'Jetzt antworten', url: APP_URL },
        })
      : renderEmail({
          accent: BRAND,
          emoji: '🤝',
          eyebrow: 'Neue Verbindung',
          heading: 'Sie wurden freigeschaltet',
          paragraphs: [
            'Ein Unternehmen hat Interesse an einer Ihrer Anzeigen freigeschaltet und kann Sie jetzt direkt kontaktieren.',
            'Wer zuerst zurückschreibt, ist im Gespräch — ein kurzer Gruß genügt für den Anfang.',
          ],
          cta: { label: 'Zur Vermittlung', url: APP_URL },
        });
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: urgent ? '🔥 Dringende Vermittlung auf Capacify' : 'Neue Vermittlung auf Capacify',
      text: mail.text,
      html: mail.html,
    });
    console.log('notifyOnGrant: email sent to poster.');
  } catch (e) {
    console.error('notifyOnGrant: send failed', e);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Branded email system (German — primary market is Hamburg). ONE responsive,
// client-safe template — table layout + inline styles, the only thing Outlook /
// Gmail / Apple Mail reliably render — shared by EVERY email below so they read
// as one product. renderEmail() returns BOTH the HTML and a plain-text
// alternative built from the same fields, so the two can never drift.
// ─────────────────────────────────────────────────────────────────────────────
const BRAND = '#FF6B00';       // Capacify orange — default accent
const BRAND_OK = '#16A34A';    // positive events (accepted, verified)
const BRAND_WARN = '#D97706';  // attention events (verification declined)
// Solid tints — email clients don't reliably support 8-digit #RRGGBBAA alpha.
const TINTS = { '#FF6B00': '#FFF1E6', '#16A34A': '#E7F6EC', '#D97706': '#FBF0E0' };
const tintFor = (accent) => TINTS[accent] || '#FFF1E6';

// Interpolated values (company names, message snippets, capacity lines) are
// user-authored — escape them before they enter the HTML template. Content is
// data, not markup.
function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// { eyebrow, emoji, heading, paragraphs[], highlight:{label,value}, cta:{label,url},
//   accent, footerNote, unsubscribeUrl } → { html, text }. Only `heading` is
//   required. `cta.url` and `unsubscribeUrl` are the fields left un-escaped
//   (both are ours — APP_URL, a Firebase link, or unsubLinkFor()).
function renderEmail({ eyebrow, emoji, heading, paragraphs = [], highlight, cta, accent = BRAND, footerNote, unsubscribeUrl }) {
  const tint = tintFor(accent);
  const f = 'Arial,Helvetica,sans-serif';
  const preheader = esc(paragraphs[0] || heading || 'Capacify');

  const bodyHtml = paragraphs
    .map((p) => `<p style="margin:0 0 14px;font:400 15px/1.65 ${f};color:#3f4652">${esc(p)}</p>`)
    .join('');

  const highlightHtml = highlight
    ? `<tr><td style="padding:6px 32px 0">
         <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${tint};border-left:4px solid ${accent};border-radius:8px">
           <tr><td style="padding:14px 16px">
             ${highlight.label ? `<div style="font:700 11px/1.4 ${f};letter-spacing:.6px;color:${accent};text-transform:uppercase">${esc(highlight.label)}</div>` : ''}
             <div style="font:800 16px/1.5 ${f};color:#111;${highlight.label ? 'margin-top:4px' : ''}">${esc(highlight.value)}</div>
           </td></tr>
         </table>
       </td></tr>`
    : '';

  const ctaHtml = cta
    ? `<tr><td style="padding:24px 32px 4px">
         <table role="presentation" cellpadding="0" cellspacing="0"><tr>
           <td align="center" style="border-radius:10px;background:${accent}">
             <a href="${cta.url}" style="display:inline-block;padding:14px 30px;font:800 15px/1 ${f};color:#ffffff;text-decoration:none;border-radius:10px">${esc(cta.label)} &nbsp;&rsaquo;</a>
           </td>
         </tr></table>
       </td></tr>`
    : '';

  const footNoteHtml = footerNote
    ? `<p style="margin:0 0 10px;font:400 12px/1.6 ${f};color:#9aa1ab">${esc(footerNote)}</p>`
    : '';

  // Visible opt-out for bulk mail. The List-Unsubscribe header (see
  // bulkMailFields) is what the mail client acts on, but Gmail's bulk-sender
  // rules also expect a clearly visible unsubscribe link in the body itself.
  const unsubHtml = unsubscribeUrl
    ? `<p style="margin:10px 0 0;font:400 11px/1.6 ${f};color:#aab0bb">
         <a href="${unsubscribeUrl}" style="color:#8b929d;text-decoration:underline">Keine solchen E-Mails mehr erhalten</a>
       </p>`
    : '';

  const html = `<!DOCTYPE html>
<html lang="de"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light only">
</head>
<body style="margin:0;padding:0;background:#eef1f4;-webkit-text-size-adjust:100%">
<span style="display:none!important;opacity:0;color:transparent;height:0;width:0;overflow:hidden;visibility:hidden">${preheader}</span>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#eef1f4">
  <tr><td align="center" style="padding:28px 12px">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px">
      <tr><td style="padding:2px 6px 18px">
        <span style="font:900 22px/1 ${f};color:#111;letter-spacing:-.5px">Capac<span style="color:${BRAND}">ify</span></span>
        <span style="font:700 12px/1 ${f};color:#9aa1ab;padding-left:8px">Hamburg</span>
      </td></tr>
      <tr><td style="background:#ffffff;border:1px solid #e6e9ee;border-radius:16px;overflow:hidden">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          <tr><td style="height:4px;background:${accent};font-size:0;line-height:0">&nbsp;</td></tr>
          <tr><td style="padding:30px 32px 0">
            ${emoji ? `<table role="presentation" cellpadding="0" cellspacing="0"><tr><td align="center" valign="middle" style="width:52px;height:52px;background:${tint};border-radius:14px;font-size:26px;line-height:52px">${emoji}</td></tr></table>` : ''}
            ${eyebrow ? `<div style="margin:18px 0 6px;font:800 11px/1.4 ${f};letter-spacing:1px;color:${accent};text-transform:uppercase">${esc(eyebrow)}</div>` : '<div style="height:16px;font-size:0;line-height:0">&nbsp;</div>'}
            <h1 style="margin:0 0 16px;font:800 23px/1.32 ${f};color:#111">${esc(heading)}</h1>
          </td></tr>
          <tr><td style="padding:0 32px">${bodyHtml}</td></tr>
          ${highlightHtml}
          ${ctaHtml}
          <tr><td style="padding:16px 32px 34px;font-size:0;line-height:0">&nbsp;</td></tr>
        </table>
      </td></tr>
      <tr><td style="padding:22px 20px 8px;text-align:center">
        ${footNoteHtml}
        <p style="margin:0 0 4px;font:700 13px/1.5 ${f};color:#6b7280">Ihr Capacify-Team</p>
        <p style="margin:0;font:400 11px/1.6 ${f};color:#aab0bb">Capacify &middot; Bau-Kapazit&auml;ten direkt vermittelt &middot; Hamburg</p>
        ${unsubHtml}
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;

  const t = ['Capacify'];
  if (eyebrow) t.push(`— ${eyebrow.toUpperCase()} —`);
  t.push('', heading, '');
  for (const p of paragraphs) t.push(p, '');
  if (highlight) t.push(`  ${highlight.label ? highlight.label + ': ' : ''}${highlight.value}`, '');
  if (cta) t.push(`${cta.label}: ${cta.url}`, '');
  if (footerNote) t.push(footerNote, '');
  t.push('Ihr Capacify-Team');
  if (unsubscribeUrl) t.push('', `Keine solchen E-Mails mehr erhalten: ${unsubscribeUrl}`);

  return { html, text: t.join('\n') };
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom-branded email verification. Firebase Auth's own sendEmailVerification()
// sends a Console-templated email via Google's shared Firebase mail infra —
// no control over its HTML, and poor deliverability on a project that hasn't
// customized that sender. This generates the SAME real Firebase Auth
// verification link (clicking it still performs the actual verification —
// this function only controls the EMAIL that carries it) but sends it through
// our own branded template and the mail pipeline already used for every other
// transactional email here. auth_service.dart calls this first and falls back
// to sendEmailVerification() client-side if it fails for any reason (SMTP not
// configured, function unreachable), so a user is never left without one.
// email is read from the caller's OWN auth token — never client-supplied — so
// this can't be abused to blast a verification link at an arbitrary address.
// ─────────────────────────────────────────────────────────────────────────────
exports.sendVerificationEmail = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const email = req.auth.token.email;
  if (!email) throw new HttpsError('failed-precondition', 'No email on this account.');
  if (req.auth.token.email_verified) return { alreadyVerified: true };

  if (!mailReady('sendVerificationEmail')) {
    throw new HttpsError('failed-precondition', 'Email delivery not configured.');
  }

  let link;
  try {
    link = await admin.auth().generateEmailVerificationLink(email, {
      url: APP_URL,
      handleCodeInApp: false,
    });
  } catch (e) {
    console.error('sendVerificationEmail: generateEmailVerificationLink failed', e);
    throw new HttpsError('internal', 'Could not create a verification link.');
  }

  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    const mail = renderEmail({
      accent: BRAND,
      emoji: '✉️',
      eyebrow: 'E-Mail bestätigen',
      heading: 'Nur noch ein Schritt',
      paragraphs: [
        'Willkommen bei Capacify! Bitte bestätigen Sie Ihre E-Mail-Adresse, um alle Funktionen freizuschalten — Anzeigen schalten, Kontakte freischalten und Nachrichten senden.',
      ],
      cta: { label: 'E-Mail-Adresse bestätigen', url: link },
      footerNote: 'Falls Sie sich nicht bei Capacify registriert haben, ignorieren Sie diese E-Mail einfach.',
    });
    await transport.sendMail({
      from: MAIL_FROM,
      to: email,
      subject: 'Bitte bestätigen Sie Ihre E-Mail-Adresse — Capacify',
      text: mail.text,
      html: mail.html,
    });
    console.log('sendVerificationEmail: sent to', email);
  } catch (e) {
    console.error('sendVerificationEmail: send failed', e);
    throw new HttpsError('internal', 'Could not send the verification email.');
  }

  return { sent: true };
});

// A short, human-readable line for a capacity, built without the app's trade
// labels (kept server-side-agnostic so it can't drift out of sync).
function capacityLine(cap) {
  const kind = cap.type === 'need' ? 'Gesuch' : 'Angebot';
  const crew = cap.workerCount ? `${cap.workerCount} Personen` : '';
  const where = cap.location || '';
  return [kind, crew, where].filter(Boolean).join(' · ');
}

// ─────────────────────────────────────────────────────────────────────────────
// Retention #1 — match alert. When a new capacity is posted, email every
// company whose SAVED SEARCH explicitly watches that trade (and matches its
// type/crew), has opted in, and isn't the poster. This is the email half of the
// in-app match alerts; together they are the core daily-habit loop.
// ─────────────────────────────────────────────────────────────────────────────
exports.notifyOnNewCapacity = onDocumentCreated('capacities/{id}', async (event) => {
  if (!mailReady('notifyOnNewCapacity')) return;
  const snap = event.data;
  if (!snap) return;
  const cap = snap.data();
  const capId = event.params.id;

  if ((cap.status || 'active') !== 'active') return;
  if (cap.contentFlagged === true) return; // don't alert on posts under review
  const trade = cap.trade;
  if (!trade) return;

  // Identity (to exclude the poster from their own alert) lives in the sidecar.
  const ownerSnap = await db().doc(`capacityOwners/${capId}`).get();
  const posterCompanyId = ownerSnap.exists ? ownerSnap.data().posterCompanyId : null;

  const searches = await db()
    .collection('savedSearches')
    .where('trades', 'array-contains', trade)
    .get();

  // Dedupe by owner (a company may have several matching searches).
  const recipients = new Map(); // ownerId -> email
  for (const s of searches.docs) {
    const sd = s.data();
    const ownerId = sd.ownerId;
    if (!ownerId || ownerId === posterCompanyId || recipients.has(ownerId)) continue;

    const t = sd.type || 'all';
    const typeOk = t === 'all' ||
      (t === 'offer' && cap.type === 'offer') ||
      (t === 'need' && cap.type === 'need');
    const crewOk = (cap.workerCount || 1) >= (sd.crewMin || 0);
    if (!typeOk || !crewOk) continue;

    const co = (await db().doc(`companies/${ownerId}`).get()).data();
    if (!co || co.emailOptIn !== true) continue;
    const ownerEmail = await companyNotifyEmail(ownerId, co);
    if (!ownerEmail) continue;
    recipients.set(ownerId, ownerEmail);
  }
  if (recipients.size === 0) return;
  warnIfUnsignedBulk('notifyOnNewCapacity');

  const transport = nodemailer.createTransport(SMTP_URL);
  const line = capacityLine(cap);
  let sent = 0;
  for (const [ownerId, email] of recipients) {
    if (sent >= 200) break; // safety cap
    if (!(await emailAllowedForUser(ownerId))) continue; // master email switch
    try {
      const mail = renderEmail({
        accent: BRAND,
        emoji: '⚡',
        eyebrow: 'Neu in Ihrem Gewerk',
        heading: 'Das könnte für Sie passen',
        paragraphs: [
          'Soeben wurde eine neue Kapazität eingestellt, die zu Ihrer gespeicherten Suche passt.',
          'Ein Blick lohnt sich — und wer zuerst schreibt, ist im Gespräch.',
        ],
        highlight: { label: 'Neue Kapazität', value: line },
        cta: { label: 'Kapazität ansehen', url: APP_URL },
        footerNote: 'Sie erhalten diese E-Mail, weil Sie Benachrichtigungen aktiviert haben — in den Einstellungen jederzeit abstellbar.',
        unsubscribeUrl: unsubLinkFor(ownerId),
      });
      // ENGAGEMENT mail → carries the one-click unsubscribe headers.
      await transport.sendMail({
        from: MAIL_FROM,
        to: email,
        subject: 'Neue passende Kapazität auf Capacify',
        text: mail.text,
        html: mail.html,
        ...bulkMailFields(ownerId),
      });
      sent++;
    } catch (e) {
      console.error('notifyOnNewCapacity: send failed', e);
    }
  }
  console.log(`notifyOnNewCapacity: ${sent} match email(s) sent for ${trade}.`);
});

// ─────────────────────────────────────────────────────────────────────────────
// Retention #2 — weekly digest. Every Monday 08:00 Berlin, email each opted-in
// company a short "your market this week" overview: how many new capacities
// appeared in their trades over the last 7 days (falls back to the whole market
// for companies with no trades set). One market query + in-memory grouping, so
// it stays cheap; skips companies with nothing relevant so we don't spam.
// ─────────────────────────────────────────────────────────────────────────────
exports.weeklyDigest = onSchedule(
  { schedule: 'every monday 08:00', timeZone: 'Europe/Berlin' },
  async () => {
    if (!mailReady('weeklyDigest')) return;
    const weekAgo = admin.firestore.Timestamp.fromMillis(
      Date.now() - 7 * 24 * 3600 * 1000
    );
    const recent = await db()
      .collection('capacities')
      .where('createdAt', '>=', weekAgo)
      .get();

    const byTrade = {};
    let total = 0;
    recent.forEach((d) => {
      const c = d.data();
      if ((c.status || 'active') !== 'active') return;
      if (c.contentFlagged === true) return;
      if (!c.trade) return;
      byTrade[c.trade] = (byTrade[c.trade] || 0) + 1;
      total++;
    });
    if (total === 0) {
      console.log('weeklyDigest: no new capacities this week — skipping.');
      return;
    }

    const companies = await db()
      .collection('companies')
      .where('emailOptIn', '==', true)
      .get();
    if (companies.empty) return;
    warnIfUnsignedBulk('weeklyDigest');

    const transport = nodemailer.createTransport(SMTP_URL);
    let sent = 0;
    for (const c of companies.docs) {
      if (sent >= 2000) break; // safety cap
      const cd = c.data();
      const digestTo = await companyNotifyEmail(c.id, cd);
      if (!digestTo) continue;
      if (!(await emailAllowedForUser(c.id))) continue; // master email switch
      const trades = Array.isArray(cd.trades) ? cd.trades : [];
      const mine = trades.length
        ? trades.reduce((n, t) => n + (byTrade[t] || 0), 0)
        : total;
      if (mine === 0) continue; // nothing relevant → don't email

      const headline = trades.length
        ? `In Ihren Gewerken gab es diese Woche ${mine} neue Kapazität(en).`
        : `Diese Woche gab es ${total} neue Kapazität(en) auf dem Markt.`;
      try {
        const mail = renderEmail({
          accent: BRAND,
          emoji: '📊',
          eyebrow: 'Ihr Wochenüberblick',
          heading: headline,
          paragraphs: [
            'Sehen Sie, wer gerade Kapazitäten sucht oder anbietet — und sichern Sie sich die passenden Kontakte, bevor es andere tun.',
          ],
          cta: { label: 'Zum Marktplatz', url: APP_URL },
          footerNote: 'Diesen Wochenüberblick können Sie in den Einstellungen jederzeit abstellen.',
          unsubscribeUrl: unsubLinkFor(c.id),
        });
        // ENGAGEMENT mail → carries the one-click unsubscribe headers.
        await transport.sendMail({
          from: MAIL_FROM,
          to: digestTo,
          subject: 'Ihr Capacify-Wochenüberblick',
          text: mail.text,
          html: mail.html,
          ...bulkMailFields(c.id),
        });
        sent++;
      } catch (e) {
        console.error('weeklyDigest: send failed', e);
      }
    }
    console.log(`weeklyDigest: ${sent} digest email(s) sent.`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Trust + CapacityOS — completed collaborations. When BOTH parties of a granted
// connection have confirmed "we worked together", count one completed
// collaboration for each company, and a repeat collaboration if this pair has
// worked together before. Incrementing runs server-side (Admin SDK bypasses
// rules) so neither company can write the other's counter or inflate its own —
// the mutual confirm is the integrity check. Idempotent: only fires on the
// transition into the both-confirmed state.
//
// Two free accounts can still mutually confirm a collaboration that never
// happened (post, request, accept, both flip their own flag — nothing here
// costs anything). That alone can't forge a rating anymore (companyRatings
// now requires its own granted-connection check, see firestore.rules), but it
// could still be used to fabricate the completedCollaborations/
// repeatCollaborations badges themselves. Two gates close that:
//   1. VERIFIED GATE — a mutual confirm only counts toward the PUBLIC badges
//      when at least one side has passed real VAT verification (raises the
//      cost from "two free signups" to "one real, checkable business").
//   2. VELOCITY CAP — even a verified pair can only add to the public badges
//      once per rolling 30 days; a burst of same-pair confirmations (e.g. by
//      posting and re-accepting repeatedly) beyond that is still recorded
//      internally (collabPairs.count, for admin/abuse visibility) but doesn't
//      keep inflating the trust signal shown to other companies.
// ─────────────────────────────────────────────────────────────────────────────
exports.onCollabConfirmed = onDocumentWritten({ document: 'contact_requests/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;

  const wasBoth = !!before && before.collabRequester === true && before.collabPoster === true;
  const isBoth = after.collabRequester === true && after.collabPoster === true;
  if (wasBoth || !isBoth) return; // only on the transition to mutually-confirmed

  const requesterId = after.requesterCompanyId;
  const posterId = after.posterCompanyId;
  if (!requesterId || !posterId || requesterId === posterId) return;

  const [requesterSnap, posterSnap] = await Promise.all([
    db().doc(`companies/${requesterId}`).get(),
    db().doc(`companies/${posterId}`).get(),
  ]);
  const eitherVerified =
    (requesterSnap.exists && requesterSnap.data().verificationStatus === 'verified') ||
    (posterSnap.exists && posterSnap.data().verificationStatus === 'verified');

  const THIRTY_DAYS_MS = 30 * 24 * 3600 * 1000;
  const pairId = [requesterId, posterId].sort().join('_');
  const pairRef = db().doc(`collabPairs/${pairId}`);

  const { countsPublicly, isRepeat } = await db().runTransaction(async (tx) => {
    const snap = await tx.get(pairRef);
    const data = snap.exists ? snap.data() : {};
    const prevPublicCount = data.publicCount || 0;
    const lastPublicCountAt = data.lastPublicCountAt || null;
    const sinceLastPublic = lastPublicCountAt ? Date.now() - lastPublicCountAt.toMillis() : Infinity;
    const countsPublicly = eitherVerified && sinceLastPublic >= THIRTY_DAYS_MS;

    const update = {
      count: (data.count || 0) + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (countsPublicly) {
      update.publicCount = prevPublicCount + 1;
      update.lastPublicCountAt = admin.firestore.FieldValue.serverTimestamp();
    }
    tx.set(pairRef, update, { merge: true });
    return { countsPublicly, isRepeat: prevPublicCount >= 1 };
  });

  if (!countsPublicly) {
    console.log(`onCollabConfirmed: ${requesterId}<->${posterId} confirmed but not publicly counted (eitherVerified=${eitherVerified}).`);
    return;
  }

  const inc = admin.firestore.FieldValue.increment(1);
  const requesterUpdate = { completedCollaborations: inc };
  const posterUpdate = { completedCollaborations: inc };
  if (isRepeat) {
    requesterUpdate.repeatCollaborations = inc;
    posterUpdate.repeatCollaborations = inc;
  }
  const batch = db().batch();
  batch.set(db().doc(`companies/${requesterId}`), requesterUpdate, { merge: true });
  batch.set(db().doc(`companies/${posterId}`), posterUpdate, { merge: true });
  await batch.commit();
  console.log(`onCollabConfirmed: counted ${requesterId}<->${posterId}${isRepeat ? ' (repeat)' : ''}.`);
});

// ─────────────────────────────────────────────────────────────────────────────
// Stalled one-sided collaboration confirmation — a real completed job could
// otherwise sit forever in "waiting for partner" limbo if the other side just
// forgets to tap confirm, silently never registering as a trust signal for
// either company. stampFirstCollabConfirm records WHEN the first side
// confirmed (no such timestamp existed before); collabConfirmNudge, on a daily
// schedule, emails+pushes the still-unconfirmed side once, 2 days later.
// Both fields are written only via Admin SDK, so no firestore.rules change is
// needed — same posture as onCollabConfirmed's own writes above.
// ─────────────────────────────────────────────────────────────────────────────
exports.stampFirstCollabConfirm = onDocumentWritten({ document: 'contact_requests/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after || after.firstCollabConfirmAt) return; // already stamped

  const wasNeither = !before || (!before.collabRequester && !before.collabPoster);
  const isExactlyOne = (after.collabRequester === true) !== (after.collabPoster === true);
  if (!(wasNeither && isExactlyOne)) return;

  await event.data.after.ref.set(
    { firstCollabConfirmAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
});

exports.collabConfirmNudge = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'Europe/Berlin' },
  async () => {
    if (!mailReady('collabConfirmNudge')) return;
    const NUDGE_AFTER_DAYS = 2;
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - NUDGE_AFTER_DAYS * 24 * 3600 * 1000
    );
    const candidates = await db()
      .collection('contact_requests')
      .where('status', '==', 'granted')
      .where('firstCollabConfirmAt', '<=', cutoff)
      .get();

    let sent = 0;
    for (const doc of candidates.docs) {
      const r = doc.data();
      if (r.collabNudgeSentAt) continue; // one-time only
      if (r.collabRequester === r.collabPoster) continue; // both confirmed, or neither
      const pendingSideIsRequester = !r.collabRequester;
      const nudgeCompanyId = pendingSideIsRequester ? r.requesterCompanyId : r.posterCompanyId;
      if (!nudgeCompanyId) continue;

      const companySnap = await db().collection('companies').doc(nudgeCompanyId).get();
      if (!companySnap.exists) continue;
      const to = await companyNotifyEmail(nudgeCompanyId, companySnap.data());
      if (!to) continue;

      try {
        if (await emailAllowedForUser(nudgeCompanyId)) {
          const transport = nodemailer.createTransport(SMTP_URL);
          const mail = renderEmail({
            accent: BRAND,
            emoji: '🤝',
            eyebrow: 'Fast geschafft',
            heading: 'Bestätigen Sie Ihre Zusammenarbeit',
            paragraphs: [
              'Ihr Verbindungspartner hat bereits bestätigt, dass die Zusammenarbeit stattgefunden hat.',
              'Mit Ihrer Bestätigung zählt sie für beide als abgeschlossen — das stärkt Ihr Profil und Ihre Sichtbarkeit auf Capacify.',
            ],
            cta: { label: 'Jetzt bestätigen', url: APP_URL },
          });
          await transport.sendMail({
            from: MAIL_FROM,
            to,
            subject: 'Zusammenarbeit bestätigen?',
            text: mail.text,
            html: mail.html,
          });
        }
        await sendPushToUser(nudgeCompanyId, {
          title: 'Zusammenarbeit bestätigen?',
          body: 'Ihr Partner wartet auf Ihre Bestätigung.',
          data: { type: 'collab_nudge', requestId: doc.id },
        });
        await db().collection('notifications').doc().set({
          recipientId: nudgeCompanyId,
          type: 'collab_nudge',
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          requestId: doc.id,
        });
        await doc.ref.set({ collabNudgeSentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        sent++;
      } catch (e) {
        console.error('collabConfirmNudge: send failed', e);
      }
    }
    console.log(`collabConfirmNudge: ${sent} nudge(s) sent.`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Pending-request nudge (#4). A message-first Anonymous request sits in 'pending'
// until the poster Accepts/Declines; if the poster never opens Anfragen the
// requester waits indefinitely and the platform's core promise silently stalls.
// Daily sweep: any 'pending' request older than 24h that hasn't been nudged pings
// the poster once (push + email + in-app). Mirrors collabConfirmNudge's one-shot
// pattern (pendingNudgeSentAt guards repeats). Filtered on status only (no
// composite index needed); age checked in memory. The pendingNudgeSentAt write
// re-triggers the onDocumentWritten contact_requests handlers, but each no-ops
// (status is unchanged, still 'pending').
// ─────────────────────────────────────────────────────────────────────────────
exports.pendingRequestNudge = onSchedule(
  { schedule: 'every day 10:00', timeZone: 'Europe/Berlin' },
  async () => {
    const NUDGE_AFTER_MS = 24 * 3600 * 1000;
    const now = Date.now();
    const pending = await db()
      .collection('contact_requests')
      .where('status', '==', 'pending')
      .get();

    let sent = 0;
    for (const doc of pending.docs) {
      const r = doc.data();
      if (r.pendingNudgeSentAt) continue; // one-time only
      if (!r.createdAt || now - r.createdAt.toMillis() < NUDGE_AFTER_MS) continue;

      // Pending Anonymous requests carry no posterCompanyId — resolve via the
      // locked owner sidecar (readable here; Admin SDK bypasses rules).
      const ownerSnap = await db().doc(`capacityOwners/${r.postId}`).get();
      if (!ownerSnap.exists) continue;
      const posterId = ownerSnap.data().posterCompanyId;
      if (!posterId) continue;

      await db().collection('notifications').doc().set({
        recipientId: posterId,
        type: 'request_pending_nudge',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        requestId: doc.id,
      });

      const userSnap = await db().collection('users').doc(posterId).get();
      if (!userSnap.exists || userSnap.data().notifyOnNewMessage !== false) {
        await sendPushToUser(posterId, {
          title: 'Anfrage wartet auf Antwort',
          body: 'Ein Unternehmen wartet seit über einem Tag auf Ihre Antwort.',
          data: { type: 'request_pending_nudge', requestId: doc.id },
        });
      }

      if (mailReady('pendingRequestNudge') && (await emailAllowedForUser(posterId))) {
        const companySnap = await db().collection('companies').doc(posterId).get();
        const to = await companyNotifyEmail(
          posterId, companySnap.exists ? companySnap.data() : null);
        if (to) {
          try {
            const transport = nodemailer.createTransport(SMTP_URL);
            const mail = renderEmail({
              accent: BRAND,
              emoji: '⏰',
              eyebrow: 'Wartet auf Sie',
              heading: 'Eine Anfrage wartet auf Ihre Antwort',
              paragraphs: [
                'Ein Unternehmen hat Ihnen vor über einem Tag eine Anfrage geschickt und wartet noch auf Ihre Rückmeldung.',
                'Eine schnelle Antwort erhöht Ihre Abschlusschance spürbar — und verbessert Ihre Antwortzeit auf dem Profil.',
              ],
              cta: { label: 'Anfrage ansehen', url: APP_URL },
            });
            await transport.sendMail({
              from: MAIL_FROM,
              to,
              subject: 'Eine Anfrage wartet auf Ihre Antwort — Capacify',
              text: mail.text,
              html: mail.html,
            });
          } catch (e) {
            console.error('pendingRequestNudge: email send failed', e);
          }
        }
      }

      await doc.ref.set(
        { pendingNudgeSentAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
      sent++;
    }
    console.log(`pendingRequestNudge: ${sent} nudge(s) sent.`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// M5 — orphan-post sweep. An anonymous post's identity lives ONLY in its
// capacityOwners/{id} sidecar (see firestore.rules), written in the SAME
// batch as the post itself. If that batch ever partially lands (client
// crash mid-write, a revoked permission between the two writes, etc.) the
// resulting post is "contactless and harmless" by rules design — no identity
// to reveal, no accept/reveal ever possible — but still clutters the public
// feed with a listing nobody can ever respond to. Daily sweep deletes any
// capacities doc older than the 1h grace period with no matching sidecar;
// the grace period is generous so this can never race a legitimate
// in-flight create (the two writes land within the same batch commit, i.e.
// milliseconds apart). Capped per run and batched in chunks of 400 (under
// Firestore's 500-writes-per-batch ceiling) — a run that hits the cap just
// finishes the rest on the next day's run.
// ─────────────────────────────────────────────────────────────────────────────
exports.sweepOrphanPosts = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'Europe/Berlin' },
  async () => {
    const ONE_HOUR_MS = 60 * 60 * 1000;
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - ONE_HOUR_MS);

    const snap = await db()
      .collection('capacities')
      .where('createdAt', '<=', cutoff)
      .limit(2000)
      .get();
    if (snap.empty) return;

    let deleted = 0;
    let batch = db().batch();
    let inBatch = 0;

    for (const doc of snap.docs) {
      const ownerSnap = await db().doc(`capacityOwners/${doc.id}`).get();
      if (ownerSnap.exists) continue;
      batch.delete(doc.ref);
      inBatch++;
      deleted++;
      if (inBatch >= 400) {
        await batch.commit();
        batch = db().batch();
        inBatch = 0;
      }
    }
    if (inBatch > 0) await batch.commit();
    console.log(`sweepOrphanPosts: deleted ${deleted} orphan post(s) out of ${snap.size} checked.`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Notifications (#9) — real, persisted records, not just client-derived
// counts. Every notification doc below is server-authored here; the client's
// only legal write is flipping `read` (see firestore.rules). Admin events fan
// out to one doc per admin uid so each admin's read state is independent.
// Push uses FCM web tokens stored on users/{uid}.fcmTokens (added by the
// client once permission is granted); dead tokens are pruned on send.
// ─────────────────────────────────────────────────────────────────────────────
async function getAdminUids() {
  const snap = await db().collection('users').where('isAdmin', '==', true).get();
  return snap.docs.map((d) => d.id);
}

async function sendPushToUser(uid, { title, body, data }) {
  const userSnap = await db().collection('users').doc(uid).get();
  const tokens = (userSnap.exists && userSnap.data().fcmTokens) || [];
  if (!tokens.length) return;

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: data || {},
    webpush: { fcmOptions: { link: APP_URL } },
  });

  // Drop tokens FCM says are dead so the array doesn't grow stale forever.
  const dead = [];
  res.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (!r.success && (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token')) {
      dead.push(tokens[i]);
    }
  });
  if (dead.length) {
    await db().collection('users').doc(uid).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead),
    });
  }
}

// Fan out one notification doc + one push per admin. Used by every
// admin-facing trigger below (verification / content flag / pending rating)
// so "something needs review" never depends on an admin having the dashboard
// open to notice it.
async function notifyAdmins({ type, pushTitle, pushBody, ...fields }) {
  const adminUids = await getAdminUids();
  if (!adminUids.length) return;

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db().batch();
  for (const uid of adminUids) {
    batch.set(db().collection('notifications').doc(), {
      recipientId: uid,
      type,
      read: false,
      createdAt: now,
      ...fields,
    });
  }
  await batch.commit();

  if (pushTitle) {
    await Promise.all(
      adminUids.map((uid) => sendPushToUser(uid, { title: pushTitle, body: pushBody || '', data: { type } }))
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New-message notification. Fires on every message write — resolves the OTHER
// participant (never the sender), records a notification, and — gated on
// their notifyOnNewMessage preference (default true) — pushes + emails them.
// Email is debounced per (chat, recipient) via a timestamp dot-keyed onto the
// chat doc itself (same 'unread.$id'/'typing.$id' idiom chat_service.dart
// already uses), so a burst of messages sends at most one email per 10 min.
// ─────────────────────────────────────────────────────────────────────────────
const MESSAGE_EMAIL_DEBOUNCE_MS = 10 * 60 * 1000;

// Response-time bands — MUST stay in sync with CapacityModel.bandResponseHours
// in lib/core/models/capacity_model.dart. An exact hour figure on a
// world-readable post is one more field an anonymous post can be joined on
// against the public companies collection, so the value is raised to the next
// band ceiling (3h → 4h) before it is stored. Rounding up never claims a
// poster is faster than they are.
const RESPONSE_HOUR_BANDS = [2, 4, 8, 24, 48, 72];

function bandResponseHours(hours) {
  if (hours === null || hours === undefined) return null;
  for (const band of RESPONSE_HOUR_BANDS) {
    if (hours <= band) return band;
  }
  // Past the last band, round up to whole days rather than pinning to a fixed
  // ceiling — a fixed cap would understate anyone slower than it.
  return Math.ceil(hours / 24) * 24;
}

// Pushes an updated posterAvgResponseHours onto every one of a poster's own
// active posts — mirrors contact_request_service.dart's Dart
// _syncResponseStatToPosts exactly, so the two response-time paths (Accept-
// based for Anonymous posts, first-chat-reply-based for auto-granted
// visible/discreet posts below) feed the identical fields and the UI needs
// zero mode-awareness. Best-effort, batched, capped defensively.
async function syncResponseStatToPosts(posterCompanyId, avgHours) {
  try {
    const owned = await db()
      .collection('capacityOwners')
      .where('posterCompanyId', '==', posterCompanyId)
      .limit(500)
      .get();
    if (owned.empty) return;
    const banded = bandResponseHours(avgHours);
    const batch = db().batch();
    owned.forEach((doc) => {
      batch.update(db().collection('capacities').doc(doc.id), {
        posterAvgResponseHours: banded === null
          ? admin.firestore.FieldValue.delete()
          : banded,
      });
    });
    await batch.commit();
  } catch (e) {
    console.error('syncResponseStatToPosts failed', e);
  }
}

exports.onNewMessage = onDocumentCreated({ document: 'chats/{chatId}/messages/{messageId}', maxInstances: 20 }, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const msg = snap.data();
  const chatId = event.params.chatId;

  const participants = Array.isArray(msg.participants) ? msg.participants : [];
  const recipientId = participants.find((p) => p !== msg.senderId);
  if (!recipientId) return;

  // Response-time reinstrumentation for auto-granted (visible/discreet)
  // posts — those have no Accept event to time (contact_request_service.dart's
  // Accept-based _recordResponseTime still owns Anonymous-mode posts,
  // unchanged). Detects the POSTER's first reply in an auto-granted chat and
  // feeds the exact same responseCount/responseSumMs/posterAvgResponseHours
  // fields that path writes. `respondedAt` (Admin-SDK-only — no client write
  // path exists, firestore.rules is untouched) guards against recounting
  // every subsequent poster message in the same thread; claimed via a
  // transaction to avoid a double-count race between concurrent writes.
  // chatId == the contact_request id ({requesterCompanyId}_{postId}).
  try {
    const reqRef = db().doc(`contact_requests/${chatId}`);
    const reqSnap = await reqRef.get();
    if (reqSnap.exists) {
      const req = reqSnap.data();
      if (!req.respondedAt && req.createdAt) {
        const capSnap = await db().doc(`capacities/${req.postId}`).get();
        const cap = capSnap.exists ? capSnap.data() : null;
        const mode = cap ? cap.visibilityMode : null;
        const posterCompanyId = cap ? cap.posterCompanyId : null;
        if ((mode === 'visible' || mode === 'discreet') && posterCompanyId && msg.senderId === posterCompanyId) {
          const ms = Date.now() - req.createdAt.toMillis();
          if (ms > 0) {
            const claimed = await db().runTransaction(async (tx) => {
              const fresh = await tx.get(reqRef);
              if (fresh.data().respondedAt) return false;
              tx.update(reqRef, { respondedAt: admin.firestore.FieldValue.serverTimestamp() });
              return true;
            });
            if (claimed) {
              const companyRef = db().collection('companies').doc(posterCompanyId);
              const avgHours = await db().runTransaction(async (tx) => {
                const compSnap = await tx.get(companyRef);
                const prevCount = (compSnap.data() && compSnap.data().responseCount) || 0;
                const prevSumMs = (compSnap.data() && compSnap.data().responseSumMs) || 0;
                const newCount = prevCount + 1;
                const newSumMs = prevSumMs + ms;
                tx.update(companyRef, { responseCount: newCount, responseSumMs: newSumMs });
                // Mirrors CompanyModel.avgResponseHours exactly (>=3 samples, min 1h).
                if (newCount < 3) return null;
                const hours = Math.ceil(newSumMs / newCount / (1000 * 60 * 60));
                return hours < 1 ? 1 : hours;
              });
              await syncResponseStatToPosts(posterCompanyId, avgHours);
            }
          }
        }
      }
    }
  } catch (e) {
    console.error('onNewMessage: response-time tracking failed', e);
  }

  const senderSnap = await db().collection('companies').doc(msg.senderId).get();
  const senderName = senderSnap.exists ? senderSnap.data().name || '' : '';

  await db().collection('notifications').doc().set({
    recipientId,
    type: 'new_message',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    chatId,
    companyId: msg.senderId,
    companyName: senderName,
  });

  const recipientUserSnap = await db().collection('users').doc(recipientId).get();
  const notifyOnNewMessage = !recipientUserSnap.exists || recipientUserSnap.data().notifyOnNewMessage !== false;
  if (!notifyOnNewMessage) return;

  await sendPushToUser(recipientId, {
    title: senderName || 'Capacify',
    body: msg.text ? msg.text.slice(0, 120) : 'Neue Nachricht',
    data: { type: 'new_message', chatId },
  });

  if (!mailReady('onNewMessage')) return;
  // Master email switch (recipientUserSnap already fetched above — no extra read).
  if (recipientUserSnap.exists && recipientUserSnap.data().notifyByEmail === false) return;

  const chatRef = db().doc(`chats/${chatId}`);
  const chatSnap = await chatRef.get();
  const notifiedEmailAt = chatSnap.exists ? chatSnap.data().notifiedEmailAt : null;
  const lastSent = notifiedEmailAt && notifiedEmailAt[recipientId] ? notifiedEmailAt[recipientId].toMillis() : 0;
  if (Date.now() - lastSent < MESSAGE_EMAIL_DEBOUNCE_MS) return;

  const recipientCompanySnap = await db().collection('companies').doc(recipientId).get();
  const to = await companyNotifyEmail(
    recipientId, recipientCompanySnap.exists ? recipientCompanySnap.data() : null);
  if (!to) return;

  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    const mail = renderEmail({
      accent: BRAND,
      emoji: '💬',
      eyebrow: 'Neue Nachricht',
      heading: senderName ? `${senderName} hat Ihnen geschrieben` : 'Sie haben eine neue Nachricht',
      paragraphs: [
        `${senderName || 'Ein Unternehmen'} hat Ihnen auf Capacify eine Nachricht gesendet. Antworten Sie direkt im Chat, um im Gespräch zu bleiben.`,
      ],
      cta: { label: 'Nachricht ansehen', url: APP_URL },
      footerNote: 'Nachrichten-Benachrichtigungen können Sie in den Einstellungen abstellen.',
    });
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: senderName ? `Neue Nachricht von ${senderName} — Capacify` : 'Neue Nachricht auf Capacify',
      text: mail.text,
      html: mail.html,
    });
    await chatRef.update({ [`notifiedEmailAt.${recipientId}`]: admin.firestore.FieldValue.serverTimestamp() });
  } catch (e) {
    console.error('onNewMessage: email send failed', e);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// New-request notification. Fires the moment a fresh 'pending' contact_request
// is created — closes the gap where a poster had NO signal that someone was
// waiting on a reply beyond manually opening the Anfragen screen (the "the
// real-time promise breaks exactly at the hand-off" gap from the audit's
// user-journey pass). Push + in-app notification always (gated on the same
// notifyOnNewMessage preference onNewMessage already uses — this is the same
// "someone wants to reach me" event, not a new preference surface); an
// immediate, non-debounced email too when the requester marked it urgent —
// non-urgent ones stay push+inbox-only so a normal browsing session doesn't
// turn into an email per message sent.
// ─────────────────────────────────────────────────────────────────────────────
exports.onNewContactRequest = onDocumentCreated({ document: 'contact_requests/{id}', maxInstances: 20 }, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const req = snap.data();
  // A visible/discreet post's request is created ALREADY 'granted' (instant
  // reveal, no Accept step) — that poster still needs to know someone just
  // messaged them, so this now fires for both statuses, not just 'pending'.
  if (req.status !== 'pending' && req.status !== 'granted') return;
  const autoGranted = req.status === 'granted';

  const ownerSnap = await db().doc(`capacityOwners/${req.postId}`).get();
  if (!ownerSnap.exists) return;
  const posterCompanyId = ownerSnap.data().posterCompanyId;
  if (!posterCompanyId) return;

  const urgent = req.urgent === true;

  await db().collection('notifications').doc().set({
    recipientId: posterCompanyId,
    type: autoGranted ? 'new_message' : 'new_contact_request',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    requestId: event.params.id,
    urgent,
  });

  const posterUserSnap = await db().collection('users').doc(posterCompanyId).get();
  const notifyOnNewMessage = !posterUserSnap.exists || posterUserSnap.data().notifyOnNewMessage !== false;
  if (!notifyOnNewMessage) return;

  await sendPushToUser(posterCompanyId, {
    // Auto-granted: the chat is already open, unlike a pending request
    // waiting on Accept — "new message" reads correctly either way.
    title: autoGranted ? (urgent ? '🔥 Dringende Nachricht' : 'Neue Nachricht') : (urgent ? '🔥 Dringende Anfrage' : 'Neue Anfrage'),
    body: req.message ? String(req.message).slice(0, 120) : 'Ein Unternehmen möchte Sie kontaktieren.',
    data: { type: autoGranted ? 'new_message' : 'new_contact_request', requestId: event.params.id },
  });

  // Auto-granted + urgent: notifyOnGrant already sends one merged email
  // carrying the urgency line for this exact event — sending this SEPARATE
  // urgent email too would double-email the poster for one event.
  if (!urgent || autoGranted || !mailReady('onNewContactRequest')) return;
  // Master email switch (posterUserSnap already fetched above — no extra read).
  if (posterUserSnap.exists && posterUserSnap.data().notifyByEmail === false) return;

  const to = ownerSnap.data().contactEmail;
  if (!to) return;
  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    const mail = renderEmail({
      accent: BRAND,
      emoji: '🔥',
      eyebrow: 'Dringende Anfrage',
      heading: 'Dringende Anfrage erhalten',
      paragraphs: [
        'Ein Unternehmen hat Ihnen eine als dringend markierte Anfrage geschickt und benötigt schnell eine Antwort.',
        'Je schneller Sie reagieren, desto größer die Chance auf den Zuschlag.',
      ],
      cta: { label: 'Anfrage ansehen', url: APP_URL },
    });
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: '🔥 Dringende Anfrage auf Capacify',
      text: mail.text,
      html: mail.html,
    });
  } catch (e) {
    console.error('onNewContactRequest: urgent email send failed', e);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Request-ACCEPTED notification (#1). Closes the REQUESTER's loop: notifyOnGrant
// above emails the POSTER when a connection reveals them, but the requester who
// sent a message and is waiting on an Anonymous post's Accept had no proactive
// signal it went through. Fires ONLY on a genuine pending→granted transition (a
// poster Accept) — never on an auto-granted (visible/discreet) request, which is
// created already 'granted' (before == null) and whose requester opened the chat
// themselves in the same action.
// ─────────────────────────────────────────────────────────────────────────────
exports.onRequestAccepted = onDocumentWritten({ document: 'contact_requests/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;
  const becameGranted = after.status === 'granted' && before && before.status !== 'granted';
  if (!becameGranted) return;

  const requesterId = after.requesterCompanyId;
  if (!requesterId) return;

  // The poster's public name for the copy (posterCompanyId is stamped on accept).
  const posterId = after.posterCompanyId;
  const posterSnap = posterId ? await db().collection('companies').doc(posterId).get() : null;
  const posterName = posterSnap && posterSnap.exists ? (posterSnap.data().name || '') : '';

  await db().collection('notifications').doc().set({
    recipientId: requesterId,
    type: 'request_accepted',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    requestId: event.params.id,
    chatId: event.params.id, // chatId == request id — lets the tile open the chat
    postId: after.postId || '',
    companyId: posterId || '',
    companyName: posterName,
  });

  // Push gated on the requester's message preference — same "someone reached me"
  // category as onNewMessage / onNewContactRequest.
  const userSnap = await db().collection('users').doc(requesterId).get();
  const notifyOnNewMessage = !userSnap.exists || userSnap.data().notifyOnNewMessage !== false;
  if (notifyOnNewMessage) {
    await sendPushToUser(requesterId, {
      title: 'Anfrage angenommen',
      body: posterName
        ? `${posterName} hat Ihre Anfrage angenommen — jetzt chatten.`
        : 'Ihre Anfrage wurde angenommen — jetzt chatten.',
      data: { type: 'request_accepted', chatId: event.params.id },
    });
  }

  // Transactional email, gated on the master switch.
  if (!mailReady('onRequestAccepted')) return;
  if (!(await emailAllowedForUser(requesterId))) return;
  const companySnap = await db().collection('companies').doc(requesterId).get();
  const to = await companyNotifyEmail(
    requesterId, companySnap.exists ? companySnap.data() : null);
  if (!to) return;
  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    const mail = renderEmail({
      accent: BRAND_OK,
      emoji: '🎉',
      eyebrow: 'Anfrage angenommen',
      heading: posterName ? `${posterName} hat Ihre Anfrage angenommen` : 'Ihre Anfrage wurde angenommen',
      paragraphs: [
        'Gute Neuigkeiten — Ihre Anfrage wurde angenommen. Sie können jetzt direkt Kontakt aufnehmen und die Details klären.',
        'Ein kurzer erster Gruß im Chat bringt das Gespräch am schnellsten in Fahrt.',
      ],
      cta: { label: 'Zum Chat', url: APP_URL },
    });
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: 'Ihre Anfrage wurde angenommen — Capacify',
      text: mail.text,
      html: mail.html,
    });
  } catch (e) {
    console.error('onRequestAccepted: email send failed', e);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Contact-request message moderation. The email/phone-leak case is handled
// preventively in firestore.rules (rejected outright — see the create rule's
// comment on why flagging-after-the-fact can't undo an already-rendered
// leak). Blocked words/slurs don't have that same "already too late" urgency,
// so they follow the same detect-and-flag pattern as capacities/companies —
// contentFlagged for admin visibility, surfaced via the existing admin
// notification fan-out rather than a new dedicated review queue (there's
// nothing to "approve" here; the connection already exists either way).
// ─────────────────────────────────────────────────────────────────────────────
exports.enforceContactRequestModeration = onDocumentCreated({ document: 'contact_requests/{id}', maxInstances: 20 }, async (event) => {
  const snap = event.data;
  if (!snap) return;
  const req = snap.data();
  if (!req.message || !moderation.containsBlockedContent(req.message)) return;

  await snap.ref.set({ contentFlagged: true }, { merge: true });
  console.log(`enforceContactRequestModeration: flagged ${event.params.id}.`);

  await notifyAdmins({
    type: 'content_flagged',
    contentType: 'contact_request',
    companyId: req.requesterCompanyId || '',
    companyName: req.requesterCompanyName || '',
    pushTitle: 'Neue Meldung',
    pushBody: 'Eine Nachricht wurde gemeldet.',
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Verification-submission notification. Fires on any companies/{id} write that
// transitions verificationStatus into 'pending' — this covers both paths a
// company reaches that state (the client's own profile save, and
// verifyMyCompany's own update above), since a write-trigger fires regardless
// of who/what performed the write.
// ─────────────────────────────────────────────────────────────────────────────
exports.onVerificationSubmitted = onDocumentWritten('companies/{id}', async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;

  const becamePending = after.verificationStatus === 'pending' && (!before || before.verificationStatus !== 'pending');
  if (!becamePending) return;

  await notifyAdmins({
    type: 'verification_submitted',
    companyId: event.params.id,
    companyName: after.name || '',
    pushTitle: 'Neue Verifizierungsanfrage',
    pushBody: after.name || '',
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Verification-RESULT notification (#2). onVerificationSubmitted above tells the
// ADMINS a review is pending; this tells the COMPANY the outcome once an admin
// approves ('verified') or rejects ('rejected') — the badge is the whole trust
// system, so the company shouldn't have to re-open their profile to learn it
// landed. verifyMyCompany's VIES path only ever sets 'pending', so a 'verified'
// or 'rejected' transition here always reflects a human decision.
// ─────────────────────────────────────────────────────────────────────────────
exports.onVerificationResult = onDocumentWritten({ document: 'companies/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;
  const prev = before ? before.verificationStatus : null;
  const cur = after.verificationStatus;
  const becameVerified = cur === 'verified' && prev !== 'verified';
  const becameRejected = cur === 'rejected' && prev !== 'rejected';
  if (!becameVerified && !becameRejected) return;

  const companyId = event.params.id;
  const outcome = becameVerified ? 'verified' : 'rejected';

  await db().collection('notifications').doc().set({
    recipientId: companyId,
    type: 'verification_result',
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    companyId,
    companyName: after.name || '',
    outcome,
  });

  await sendPushToUser(companyId, {
    title: becameVerified ? 'Verifizierung bestätigt' : 'Verifizierung abgelehnt',
    body: becameVerified
      ? 'Ihr Unternehmen ist jetzt verifiziert.'
      : 'Ihre Verifizierung konnte nicht bestätigt werden. Bitte prüfen Sie Ihre Angaben.',
    data: { type: 'verification_result', outcome },
  });

  if (!mailReady('onVerificationResult')) return;
  if (!(await emailAllowedForUser(companyId))) return;
  const to = await companyNotifyEmail(companyId, after);
  if (!to) return;
  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    const mail = becameVerified
      ? renderEmail({
          accent: BRAND_OK,
          emoji: '✅',
          eyebrow: 'Verifiziert',
          heading: 'Ihr Unternehmen ist verifiziert',
          paragraphs: [
            'Herzlichen Glückwunsch! Ihr Unternehmen wurde erfolgreich verifiziert.',
            'Das Verifiziert-Abzeichen ist ab sofort auf Ihrem Profil sichtbar — es schafft Vertrauen und hebt Sie bei potenziellen Partnern hervor.',
          ],
          cta: { label: 'Zum Profil', url: APP_URL },
        })
      : renderEmail({
          accent: BRAND_WARN,
          emoji: '⚠️',
          eyebrow: 'Verifizierung',
          heading: 'Verifizierung nicht bestätigt',
          paragraphs: [
            'Ihre Verifizierung konnte leider nicht bestätigt werden.',
            'Bitte überprüfen Sie Ihre Unternehmensangaben — insbesondere die USt-IdNr. — und starten Sie die Verifizierung anschließend erneut.',
          ],
          cta: { label: 'Angaben prüfen', url: APP_URL },
        });
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: becameVerified
        ? 'Ihr Unternehmen ist verifiziert — Capacify'
        : 'Ihre Verifizierung — Capacify',
      text: mail.text,
      html: mail.html,
    });
  } catch (e) {
    console.error('onVerificationResult: email send failed', e);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Trust integrity — SERVER-SIDE moderation enforcement. content_moderation.dart's
// shouldFlagDescription() only runs in the Flutter client before a save; a
// direct authenticated write to the Firestore REST/gRPC API (trivial with any
// valid ID token) skips it entirely and publishes unfiltered text with
// contentFlagged defaulting to false — the anonymization/moderation guarantee
// the product is named after was, until this trigger, a client-side suggestion
// rather than an enforced one. This re-runs the same check (ported to JS in
// moderation.js) on every write and force-flags server-side via the Admin SDK,
// which bypasses rules entirely — so it can set contentFlagged=true even
// though non-admin clients may only ever move it false→true themselves.
// Guarded to only re-check when the relevant text actually changed, since a
// merge-write from recomputeCompanyRating/onCollabConfirmed also triggers this
// (touches companies/{id} without touching name/description/certifications).
// ─────────────────────────────────────────────────────────────────────────────
exports.enforceCapacityModeration = onDocumentWritten({ document: 'capacities/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;
  if (after.contentFlagged === true) return; // already flagged, nothing to do

  const descriptionChanged = !before || before.description !== after.description;
  if (!descriptionChanged) return;

  if (moderation.shouldFlagText(after.description)) {
    await event.data.after.ref.set({ contentFlagged: true }, { merge: true });
    console.log(`enforceCapacityModeration: flagged ${event.params.id}.`);
  }
});

// H2 — sequential deal numbers used to be assigned by the CLIENT, drawing
// from counters/deals via a rule that only checked "value == resource.value
// + 1". That let any signed-in account bump the shared counter directly
// (repeated +1 writes with no tie to a real deal closure) — corrupting/
// inflating the sequence and making counters/deals a write-contention
// hotspot every real closure also had to contend with. Moved server-side:
// the client now only sets status:'closed' (still gated to the post's owner
// by the capacities update rule), and THIS trigger — Admin SDK, bypasses
// rules — is what actually draws the next number, in its own transaction,
// the moment a capacity's status lands on 'closed' for the first time.
// dealNumber is now pinned unchanged in the owner's own capacities update
// branch (see firestore.rules) and counters/deals is closed to all client
// writes, so this trigger is the only path to either field.
exports.assignDealNumber = onDocumentWritten({ document: 'capacities/{id}', maxInstances: 20 }, async (event) => {
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;
  if (after.status !== 'closed') return;
  if (after.dealNumber != null) return; // already numbered — keeps it stable across reopen/re-close

  const capacityRef = event.data.after.ref;
  const counterRef = db().collection('counters').doc('deals');

  await db().runTransaction(async (tx) => {
    const [capacitySnap, counterSnap] = await Promise.all([tx.get(capacityRef), tx.get(counterRef)]);
    const capacityData = capacitySnap.data();
    if (!capacityData || capacityData.status !== 'closed' || capacityData.dealNumber != null) return;

    const nextNumber = ((counterSnap.data() || {}).value || 0) + 1;
    tx.set(counterRef, { value: nextNumber });
    tx.update(capacityRef, { dealNumber: nextNumber });
  });

  console.log(`assignDealNumber: numbered ${event.params.id}.`);
});

// Same enforcement for companies (name/description/certifications), PLUS
// impersonation detection: a new or renamed company whose name is suspiciously
// close to an already VIES-verified company's registered legal name gets
// routed into the same admin Moderation queue instead of going live unreviewed
// (companies/{companyId} has no uniqueness constraint on `name`, so nothing
// else stops "Müller Dach GmbH" from being registered by someone who isn't
// Müller Dach GmbH). Both checks share one trigger to avoid double-reading
// the doc and issuing two competing writes on the same event.
exports.enforceCompanyIntegrity = onDocumentWritten({ document: 'companies/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;
  const companyId = event.params.id;
  if (after.contentFlagged === true) return; // already flagged, nothing to do

  const textChanged = !before ||
    before.name !== after.name ||
    before.description !== after.description ||
    before.certifications !== after.certifications;
  if (textChanged) {
    const text = [after.name, after.description, after.certifications].filter(Boolean).join(' ');
    if (moderation.shouldFlagText(text)) {
      await event.data.after.ref.set({ contentFlagged: true, flagReason: 'moderation' }, { merge: true });
      console.log(`enforceCompanyIntegrity: flagged ${companyId} (moderation).`);
      return;
    }
  }

  const nameChanged = !before || before.name !== after.name;
  if (nameChanged && after.name) {
    const verified = await db().collection('companies').where('vatValid', '==', true).get();
    for (const doc of verified.docs) {
      if (doc.id === companyId) continue;
      const otherName = doc.data().vatVerifiedName;
      if (!otherName) continue;
      if (moderation.nameSimilarity(after.name, otherName) >= 0.8) {
        await event.data.after.ref.set({
          contentFlagged: true,
          flagReason: 'impersonation',
          flagDetail: otherName,
        }, { merge: true });
        console.log(`enforceCompanyIntegrity: flagged ${companyId} (impersonation of "${otherName}").`);
        return;
      }
    }
  }

  // Duplicate VAT — the same real business's VAT number registered against a
  // second account (one honest company with two logins, or one actor running
  // a sock-puppet pair under a real number they don't control).
  // H4 fix: this used to pull EVERY vatValid:true company and normalize+
  // compare each one's vatNumber in memory — an O(n) full scan of the
  // verified set on every profile edit that touched name/VAT, growing with
  // the platform. verifyMyCompany now stamps vatNumberNormalized on every
  // successful VIES check, so this can be a single equality query instead.
  // Docs verified before this field existed self-heal below the first time
  // they go through this trigger again.
  const vatChanged = !before || before.vatNumber !== after.vatNumber || before.vatValid !== after.vatValid;
  if (vatChanged && after.vatValid === true && after.vatNumber) {
    const normalized = String(after.vatNumber).toUpperCase().replace(/\s/g, '');
    const candidates = await db().collection('companies')
      .where('vatNumberNormalized', '==', normalized)
      .get();
    const dupe = candidates.docs.find((doc) => doc.id !== companyId && doc.data().vatValid === true);
    if (dupe) {
      await event.data.after.ref.set({
        contentFlagged: true,
        flagReason: 'duplicate_vat',
        flagDetail: dupe.data().name || '',
        vatNumberNormalized: normalized,
      }, { merge: true });
      console.log(`enforceCompanyIntegrity: flagged ${companyId} (VAT also used by "${dupe.data().name || dupe.id}").`);
      return;
    }
    // Self-heal: keep the index field in sync for docs that predate it or
    // were edited directly. Only fires when it's actually stale, so it
    // doesn't re-trigger itself (vatChanged is false on the resulting write).
    if (after.vatNumberNormalized !== normalized) {
      await event.data.after.ref.set({ vatNumberNormalized: normalized }, { merge: true });
    }
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Content-flag notifications. Fire when a capacity or company transitions
// contentFlagged false→true (the only legal non-admin change to that field —
// see firestore.rules) — every admin gets notified so the Moderation queue
// doesn't rely on someone having the dashboard open to notice it.
// ─────────────────────────────────────────────────────────────────────────────
exports.onCapacityFlagged = onDocumentWritten({ document: 'capacities/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;

  const becameFlagged = after.contentFlagged === true && (!before || before.contentFlagged !== true);
  if (!becameFlagged) return;

  await notifyAdmins({
    type: 'content_flagged',
    contentType: 'capacity',
    capacityId: event.params.id,
    pushTitle: 'Neue Meldung',
    pushBody: 'Ein Beitrag wurde gemeldet.',
  });
});

exports.onCompanyFlagged = onDocumentWritten({ document: 'companies/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;

  const becameFlagged = after.contentFlagged === true && (!before || before.contentFlagged !== true);
  if (!becameFlagged) return;

  await notifyAdmins({
    type: 'content_flagged',
    contentType: 'company',
    companyId: event.params.id,
    companyName: after.name || '',
    pushTitle: 'Neue Meldung',
    pushBody: after.name || '',
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Reviews — keep the denormalized rating aggregate correct. ratingSum/ratingCount
// are admin-only writable (anti-tamper), so a rater deleting their own review
// can't decrement them from the client → the score stays inflated. This trigger
// recomputes the aggregate from the APPROVED reviews on EVERY companyRatings
// write (create / approve / reject / delete), server-side, so it's always exact.
// Single equality filter (no composite index needed); status filtered in memory.
// ─────────────────────────────────────────────────────────────────────────────
async function recomputeCompanyRating(companyId) {
  const snap = await db()
    .collection('companyRatings')
    .where('companyId', '==', companyId)
    .get();
  let sum = 0;
  let count = 0;
  snap.forEach((d) => {
    const r = d.data();
    if (r.status === 'approved' && typeof r.rating === 'number') {
      sum += r.rating;
      count++;
    }
  });
  await db().doc(`companies/${companyId}`).set(
    { ratingSum: sum, ratingCount: count },
    { merge: true },
  );
  return { sum, count };
}

exports.onRatingWrite = onDocumentWritten({ document: 'companyRatings/{id}', maxInstances: 20 }, async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  const companyId = (after && after.companyId) || (before && before.companyId);
  if (!companyId) return;

  const { sum, count } = await recomputeCompanyRating(companyId);
  console.log(`onRatingWrite: ${companyId} → sum=${sum} count=${count}`);

  // Admin fan-out only on genuine creation of a still-pending rating — not on
  // every write (approve/reject/delete already surface via the queue itself).
  const isNewPending = !before && after && after.status === 'pending';
  if (isNewPending) {
    await notifyAdmins({
      type: 'rating_submitted',
      ratingId: event.params.id,
      companyId,
      companyName: after.ratedCompanyName || '',
      pushTitle: 'Neue Bewertung zur Freigabe',
      pushBody: after.ratedCompanyName || '',
    });
  }

  // #3 — tell the RATED company when their review goes live (status → approved).
  // Only on the transition into 'approved', so a later edit/recompute doesn't
  // re-notify. Push + in-app only (a low-value email path we deliberately skip).
  const becameApproved = after && after.status === 'approved' && (!before || before.status !== 'approved');
  if (becameApproved) {
    await db().collection('notifications').doc().set({
      recipientId: companyId,
      type: 'rating_approved',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      companyId,
      companyName: after.ratedCompanyName || '',
      ratingId: event.params.id,
      rating: typeof after.rating === 'number' ? after.rating : 0,
    });
    await sendPushToUser(companyId, {
      title: 'Neue Bewertung',
      body: after.rating
        ? `Sie haben eine neue Bewertung erhalten: ${after.rating}/5 Sternen.`
        : 'Sie haben eine neue Bewertung erhalten.',
      data: { type: 'rating_approved' },
    });
  }
});

// The one-time admin backfill callable (recomputeAllRatingAggregates) that
// used to live here has been removed — it was broken (rejected before ever
// reaching this file's own logging, root cause never confirmed) and, more to
// the point, redundant: onRatingWrite above already keeps every company's
// aggregate correct on every create/approve/reject/delete going forward, so
// there's no live drift left for a manual recompute to fix except whatever
// specific companies were already stale before that trigger existed. If a
// specific company's star rating and review list ever visibly disagree again
// (see the audit's finding 07), recomputeCompanyRating() above can still be
// invoked directly for that one company id — there's just no standing UI
// button for an all-companies sweep anymore.
