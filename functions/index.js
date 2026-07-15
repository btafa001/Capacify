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
// have opted in (companies/{id}.emailOptIn == true). Every email/push path is
// a no-op until SMTP_URL / an FCM token exists, so the app is unaffected until then.
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const moderation = require('./moderation');

admin.initializeApp();
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
exports.uploadCompanyLogo = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const { base64Data, contentType } = req.data || {};
  if (!base64Data || typeof base64Data !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing image data.');
  }
  if (!contentType || typeof contentType !== 'string' || !contentType.startsWith('image/')) {
    throw new HttpsError('invalid-argument', 'File must be an image.');
  }

  let buffer;
  try {
    buffer = Buffer.from(base64Data, 'base64');
  } catch (e) {
    throw new HttpsError('invalid-argument', 'Could not read the image data.');
  }
  // The authoritative cap — this Admin SDK write is the only path that can
  // actually reach Storage, so this is what really bounds per-logo cost, not
  // the client's own pre-check. The client already resizes to max 512px
  // before it gets here, so a real photo should land well under this.
  if (buffer.length === 0 || buffer.length >= 1024 * 1024) {
    throw new HttpsError('invalid-argument', 'File must be a non-empty image under 1 MB.');
  }

  const uid = req.auth.uid;
  const path = `company_logos/${uid}/logo`;
  const token = crypto.randomUUID();
  const bucket = admin.storage().bucket();

  try {
    await bucket.file(path).save(buffer, {
      contentType,
      metadata: { metadata: { firebaseStorageDownloadTokens: token } },
    });
  } catch (e) {
    console.error('uploadCompanyLogo: save failed', e);
    throw new HttpsError('internal', 'Could not upload the logo.');
  }

  const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
  return { url };
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
const MAIL_FROM = process.env.MAIL_FROM || 'Capacify <onboarding@resend.dev>';
const APP_URL = process.env.APP_URL || 'https://capacify.de';

exports.notifyOnGrant = onDocumentWritten('contact_requests/{id}', async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;

  const becameGranted = after.status === 'granted' && (!before || before.status !== 'granted');
  if (!becameGranted) return;

  if (!SMTP_URL) {
    console.log('notifyOnGrant: no SMTP_URL configured — skipping email.');
    return;
  }

  // The poster's contact email lives only in the locked sidecar.
  const owner = (await db().doc(`capacityOwners/${after.postId}`).get()).data();
  const to = owner && owner.contactEmail;
  if (!to) {
    console.log('notifyOnGrant: no poster email found for post', after.postId);
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
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: urgent ? '🔥 Dringende Vermittlung auf Capacify' : 'Neue Vermittlung auf Capacify',
      text:
        'Guten Tag,\n\n' +
        (urgent
          ? 'ein Unternehmen hat über Capacify Interesse an einer Ihrer Anzeigen freigeschaltet und als DRINGEND markiert — es benötigt schnell eine Antwort.\n\n'
          : 'ein Unternehmen hat über Capacify Interesse an einer Ihrer Anzeigen freigeschaltet ' +
            'und kann Sie nun direkt kontaktieren.\n\n') +
        'Melden Sie sich an, um zu antworten:\n\n' +
        `${APP_URL}\n\n` +
        'Ihr Capacify-Team',
      html:
        `<p>Guten Tag,</p>` +
        (urgent
          ? `<p>ein Unternehmen hat über <strong>Capacify</strong> Interesse an einer Ihrer Anzeigen freigeschaltet und <strong>als dringend markiert</strong> — es benötigt schnell eine Antwort.</p>`
          : `<p>ein Unternehmen hat über <strong>Capacify</strong> Interesse an einer Ihrer Anzeigen ` +
            `freigeschaltet und kann Sie nun direkt kontaktieren.</p>`) +
        `<p><a href="${APP_URL}" style="background:#FF6B00;color:#fff;padding:10px 18px;` +
        `border-radius:8px;text-decoration:none;font-weight:700">Zur Vermittlung</a></p>` +
        `<p style="color:#888;font-size:12px">Ihr Capacify-Team</p>`,
    });
    console.log('notifyOnGrant: email sent to poster.');
  } catch (e) {
    console.error('notifyOnGrant: send failed', e);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Retention helpers + email templates (German — primary market is Hamburg).
// ─────────────────────────────────────────────────────────────────────────────
const BTN =
  'background:#FF6B00;color:#fff;padding:10px 18px;border-radius:8px;' +
  'text-decoration:none;font-weight:700;display:inline-block';
const FOOT = '<p style="color:#888;font-size:12px">Ihr Capacify-Team</p>';

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

  if (!SMTP_URL) {
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
    await transport.sendMail({
      from: MAIL_FROM,
      to: email,
      subject: 'Bitte bestätigen Sie Ihre E-Mail-Adresse — Capacify',
      text:
        'Guten Tag,\n\n' +
        'bitte bestätigen Sie Ihre E-Mail-Adresse, um Capacify vollständig nutzen zu können:\n\n' +
        `${link}\n\n` +
        'Falls Sie sich nicht bei Capacify registriert haben, ignorieren Sie diese E-Mail einfach.\n\n' +
        'Ihr Capacify-Team',
      html:
        `<p>Guten Tag,</p>` +
        `<p>bitte bestätigen Sie Ihre E-Mail-Adresse, um <strong>Capacify</strong> vollständig nutzen zu können.</p>` +
        `<p><a href="${link}" style="${BTN}">E-Mail-Adresse bestätigen</a></p>` +
        `<p style="color:#888;font-size:12px">Falls Sie sich nicht bei Capacify registriert haben, ignorieren Sie diese E-Mail einfach.</p>` +
        FOOT,
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
  if (!SMTP_URL) {
    console.log('notifyOnNewCapacity: no SMTP_URL — skipping.');
    return;
  }
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
    if (!co || co.emailOptIn !== true || !co.email) continue;
    recipients.set(ownerId, co.email);
  }
  if (recipients.size === 0) return;

  const transport = nodemailer.createTransport(SMTP_URL);
  const line = capacityLine(cap);
  let sent = 0;
  for (const [, email] of recipients) {
    if (sent >= 200) break; // safety cap
    try {
      await transport.sendMail({
        from: MAIL_FROM,
        to: email,
        subject: 'Neue passende Kapazität auf Capacify',
        text:
          'Guten Tag,\n\n' +
          'in Ihrem Gewerk wurde soeben eine neue Kapazität eingestellt:\n\n' +
          `${line}\n\n` +
          'Jetzt ansehen und direkt eine Nachricht senden:\n' +
          `${APP_URL}\n\n` +
          'Ihr Capacify-Team\n\n' +
          '— Sie erhalten diese E-Mail, weil Sie Benachrichtigungen aktiviert haben. ' +
          'In den Einstellungen können Sie sie jederzeit abstellen.',
        html:
          `<p>Guten Tag,</p>` +
          `<p>in Ihrem Gewerk wurde soeben eine neue Kapazität eingestellt:</p>` +
          `<p style="font-size:16px;font-weight:700">${line}</p>` +
          `<p><a href="${APP_URL}" style="${BTN}">Kapazität ansehen</a></p>` +
          FOOT +
          `<p style="color:#aaa;font-size:11px">Sie erhalten diese E-Mail, weil Sie ` +
          `Benachrichtigungen aktiviert haben. In den Einstellungen abstellbar.</p>`,
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
    if (!SMTP_URL) {
      console.log('weeklyDigest: no SMTP_URL — skipping.');
      return;
    }
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

    const transport = nodemailer.createTransport(SMTP_URL);
    let sent = 0;
    for (const c of companies.docs) {
      if (sent >= 2000) break; // safety cap
      const cd = c.data();
      if (!cd.email) continue;
      const trades = Array.isArray(cd.trades) ? cd.trades : [];
      const mine = trades.length
        ? trades.reduce((n, t) => n + (byTrade[t] || 0), 0)
        : total;
      if (mine === 0) continue; // nothing relevant → don't email

      const headline = trades.length
        ? `In Ihren Gewerken gab es diese Woche ${mine} neue Kapazität(en).`
        : `Diese Woche gab es ${total} neue Kapazität(en) auf dem Markt.`;
      try {
        await transport.sendMail({
          from: MAIL_FROM,
          to: cd.email,
          subject: 'Ihr Capacify-Wochenüberblick',
          text:
            'Guten Tag,\n\n' +
            `${headline}\n\n` +
            'Sehen Sie, wer gerade Kapazitäten sucht oder anbietet:\n' +
            `${APP_URL}\n\n` +
            'Ihr Capacify-Team\n\n' +
            '— In den Einstellungen können Sie diese E-Mails jederzeit abstellen.',
          html:
            `<p>Guten Tag,</p>` +
            `<p style="font-size:16px;font-weight:700">${headline}</p>` +
            `<p>Sehen Sie, wer gerade Kapazitäten sucht oder anbietet.</p>` +
            `<p><a href="${APP_URL}" style="${BTN}">Zum Marktplatz</a></p>` +
            FOOT +
            `<p style="color:#aaa;font-size:11px">In den Einstellungen abstellbar.</p>`,
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
    if (!SMTP_URL) {
      console.log('collabConfirmNudge: no SMTP_URL — skipping.');
      return;
    }
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
      if (!companySnap.exists || !companySnap.data().email) continue;
      const to = companySnap.data().email;

      try {
        const transport = nodemailer.createTransport(SMTP_URL);
        await transport.sendMail({
          from: MAIL_FROM,
          to,
          subject: 'Zusammenarbeit bestätigen?',
          text:
            'Guten Tag,\n\n' +
            'Ihr Verbindungspartner hat bereits bestätigt, dass die Zusammenarbeit stattgefunden hat. ' +
            'Bitte bestätigen Sie ebenfalls, damit sie für beide als abgeschlossen zählt.\n\n' +
            `${APP_URL}\n\nIhr Capacify-Team`,
          html:
            `<p>Guten Tag,</p>` +
            `<p>Ihr Verbindungspartner hat bereits bestätigt, dass die Zusammenarbeit stattgefunden hat. ` +
            `Bitte bestätigen Sie ebenfalls, damit sie für beide als abgeschlossen zählt.</p>` +
            `<p><a href="${APP_URL}" style="${BTN}">Jetzt bestätigen</a></p>` +
            FOOT,
        });
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
    const batch = db().batch();
    owned.forEach((doc) => {
      batch.update(db().collection('capacities').doc(doc.id), {
        posterAvgResponseHours: avgHours === null || avgHours === undefined
          ? admin.firestore.FieldValue.delete()
          : avgHours,
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

  if (!SMTP_URL) return;

  const chatRef = db().doc(`chats/${chatId}`);
  const chatSnap = await chatRef.get();
  const notifiedEmailAt = chatSnap.exists ? chatSnap.data().notifiedEmailAt : null;
  const lastSent = notifiedEmailAt && notifiedEmailAt[recipientId] ? notifiedEmailAt[recipientId].toMillis() : 0;
  if (Date.now() - lastSent < MESSAGE_EMAIL_DEBOUNCE_MS) return;

  const recipientCompanySnap = await db().collection('companies').doc(recipientId).get();
  const to = recipientCompanySnap.exists ? recipientCompanySnap.data().email : null;
  if (!to) return;

  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: 'Neue Nachricht auf Capacify',
      text:
        'Guten Tag,\n\n' +
        `${senderName || 'Ein Unternehmen'} hat Ihnen auf Capacify eine Nachricht geschrieben.\n\n` +
        `${APP_URL}\n\n` +
        'Ihr Capacify-Team\n\n' +
        '— In den Einstellungen können Sie diese E-Mails jederzeit abstellen.',
      html:
        `<p>Guten Tag,</p>` +
        `<p><strong>${senderName || 'Ein Unternehmen'}</strong> hat Ihnen auf Capacify eine Nachricht geschrieben.</p>` +
        `<p><a href="${APP_URL}" style="${BTN}">Nachricht ansehen</a></p>` +
        FOOT +
        `<p style="color:#aaa;font-size:11px">In den Einstellungen abstellbar.</p>`,
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
  if (!SMTP_URL || !urgent || autoGranted) return;

  const to = ownerSnap.data().contactEmail;
  if (!to) return;
  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: '🔥 Dringende Anfrage auf Capacify',
      text:
        'Guten Tag,\n\n' +
        'ein Unternehmen hat Ihnen eine als DRINGEND markierte Anfrage geschickt und benötigt schnell eine Antwort.\n\n' +
        `${APP_URL}\n\n` +
        'Ihr Capacify-Team',
      html:
        `<p>Guten Tag,</p>` +
        `<p>ein Unternehmen hat Ihnen eine <strong>als dringend markierte</strong> Anfrage geschickt und benötigt schnell eine Antwort.</p>` +
        `<p><a href="${APP_URL}" style="${BTN}">Anfrage ansehen</a></p>` +
        FOOT,
    });
  } catch (e) {
    console.error('onNewContactRequest: urgent email send failed', e);
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
  // a sock-puppet pair under a real number they don't control). vatNumber
  // isn't stored pre-normalized, so compare on a normalized copy in memory
  // rather than relying on an exact-match Firestore query.
  const vatChanged = !before || before.vatNumber !== after.vatNumber || before.vatValid !== after.vatValid;
  if (vatChanged && after.vatValid === true && after.vatNumber) {
    const normalized = String(after.vatNumber).toUpperCase().replace(/\s/g, '');
    const verified = await db().collection('companies').where('vatValid', '==', true).get();
    for (const doc of verified.docs) {
      if (doc.id === companyId) continue;
      const otherVat = String(doc.data().vatNumber || '').toUpperCase().replace(/\s/g, '');
      if (otherVat && otherVat === normalized) {
        await event.data.after.ref.set({
          contentFlagged: true,
          flagReason: 'duplicate_vat',
          flagDetail: doc.data().name || '',
        }, { merge: true });
        console.log(`enforceCompanyIntegrity: flagged ${companyId} (VAT also used by "${doc.data().name || doc.id}").`);
        return;
      }
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
