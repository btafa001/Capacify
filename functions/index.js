// Capacify Cloud Functions (2nd gen).
//
// Cost posture: europe-west3 (EU data residency), maxInstances capped so a
// traffic spike can't runaway-bill, and no minInstances (zero idle compute).
// At pre-launch volume this sits inside the free tier.
//
// Jobs:
//   • verifyMyCompany     — H3: live EU VIES VAT check, kills the manual verify bottleneck
//   • purgeUserData       — H8/M1: recursive GDPR erasure of chats the client can't hard-delete
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
const nodemailer = require('nodemailer');

admin.initializeApp();
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

  try {
    const transport = nodemailer.createTransport(SMTP_URL);
    await transport.sendMail({
      from: MAIL_FROM,
      to,
      subject: 'Neue Vermittlung auf Capacify',
      text:
        'Guten Tag,\n\n' +
        'ein Unternehmen hat über Capacify Interesse an einer Ihrer Anzeigen freigeschaltet ' +
        'und kann Sie nun direkt kontaktieren. Melden Sie sich an, um zu antworten:\n\n' +
        `${APP_URL}\n\n` +
        'Ihr Capacify-Team',
      html:
        `<p>Guten Tag,</p>` +
        `<p>ein Unternehmen hat über <strong>Capacify</strong> Interesse an einer Ihrer Anzeigen ` +
        `freigeschaltet und kann Sie nun direkt kontaktieren.</p>` +
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
// ─────────────────────────────────────────────────────────────────────────────
exports.onCollabConfirmed = onDocumentWritten('contact_requests/{id}', async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;

  const wasBoth = !!before && before.collabRequester === true && before.collabPoster === true;
  const isBoth = after.collabRequester === true && after.collabPoster === true;
  if (wasBoth || !isBoth) return; // only on the transition to mutually-confirmed

  const requesterId = after.requesterCompanyId;
  const posterId = after.posterCompanyId;
  if (!requesterId || !posterId || requesterId === posterId) return;

  const inc = admin.firestore.FieldValue.increment(1);

  // Repeat detection via an order-independent per-pair counter.
  const pairId = [requesterId, posterId].sort().join('_');
  const pairRef = db().doc(`collabPairs/${pairId}`);
  const isRepeat = await db().runTransaction(async (tx) => {
    const snap = await tx.get(pairRef);
    const prev = snap.exists ? (snap.data().count || 0) : 0;
    tx.set(pairRef, {
      count: prev + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return prev >= 1; // already collaborated before → this one is a repeat
  });

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

exports.onNewMessage = onDocumentCreated('chats/{chatId}/messages/{messageId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const msg = snap.data();
  const chatId = event.params.chatId;

  const participants = Array.isArray(msg.participants) ? msg.participants : [];
  const recipientId = participants.find((p) => p !== msg.senderId);
  if (!recipientId) return;

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
// Content-flag notifications. Fire when a capacity or company transitions
// contentFlagged false→true (the only legal non-admin change to that field —
// see firestore.rules) — every admin gets notified so the Moderation queue
// doesn't rely on someone having the dashboard open to notice it.
// ─────────────────────────────────────────────────────────────────────────────
exports.onCapacityFlagged = onDocumentWritten('capacities/{id}', async (event) => {
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

exports.onCompanyFlagged = onDocumentWritten('companies/{id}', async (event) => {
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

exports.onRatingWrite = onDocumentWritten('companyRatings/{id}', async (event) => {
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

// ─────────────────────────────────────────────────────────────────────────────
// One-time backfill: the aggregate is only correct going forward from
// onRatingWrite's deploy. Any company whose rating was already inflated by a
// PAST deletion (before this trigger existed) stays wrong until touched — this
// admin-triggered callable recomputes every company's ratingSum/ratingCount
// from the approved companyRatings docs, once, to fix any existing bad data.
// ─────────────────────────────────────────────────────────────────────────────
exports.recomputeAllRatingAggregates = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const callerDoc = await db().collection('users').doc(req.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data().isAdmin !== true) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }

  const companies = await db().collection('companies').get();
  let updated = 0;
  for (const doc of companies.docs) {
    await recomputeCompanyRating(doc.id);
    updated++;
  }
  console.log(`recomputeAllRatingAggregates: ${updated} companies recomputed.`);
  return { updated };
});
