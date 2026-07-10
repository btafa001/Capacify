# Email notifications — "you got a new interest"

## What ships now (no backend)

- **In-app badge**: the sidebar "Erhaltene Anfragen" item shows a count of `pending`
  contact requests (new interest awaiting your response). Live, secure, client-only.
- **Preference**: Settings → Benachrichtigungen → "E-Mail Benachrichtigungen" persists
  `users/{uid}.notifyByEmail` (default `true`). This is the on/off switch.

## Why email itself needs a small backend

The anonymization is the blocker, not laziness: a **requester** triggers the "new
interest" event, but the requester is deliberately forbidden from reading the **poster's**
email (it lives in the locked `capacityOwners/{postId}` sidecar). So the client that fires
the event physically cannot address an email to the recipient. Resolving `postId → poster
email` requires admin privileges — i.e. a server. There is **no secure client-only path**
for this direction; that's the security model working as designed.

The send is one Firestore-triggered Cloud Function. It needs the **Blaze** plan (pay-as-you-go;
in practice free at this volume). Everything the function needs already exists in the app.

## Turnkey setup (~10 min, when ready)

1. Upgrade the project to **Blaze**.
2. Install the **"Trigger Email from Firestore"** extension (SendGrid/SMTP of your choice);
   point it at a `mail` collection.
3. Deploy the function below.

```js
// functions/index.js  —  Node 18, firebase-functions v2
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
initializeApp();
const db = getFirestore();

// Fires when a requester creates a contact request. Admin context CAN read the
// locked owner sidecar, so it resolves the poster's email — which the client never sees.
exports.notifyPosterOnRequest = onDocumentCreated("contact_requests/{reqId}", async (event) => {
  const req = event.data?.data();
  if (!req) return;
  // Only notify the poster for requests that reached them (verified → 'pending').
  // 'pending_review' is still with the founder; skip until it's approved.
  if (req.status !== "pending") return;

  const ownerSnap = await db.doc(`capacityOwners/${req.postId}`).get();
  const owner = ownerSnap.data();
  if (!owner) return;
  const posterEmail = owner.contactEmail;
  const posterUid = owner.posterCompanyId;
  if (!posterEmail) return;

  // Respect the poster's toggle (default ON when unset).
  const userSnap = await db.doc(`users/${posterUid}`).get();
  if (userSnap.get("notifyByEmail") === false) return;

  const city = req.requesterCity || "Hamburg";
  const verified = req.requesterVerified ? "verifiziertes " : "";
  await db.collection("mail").add({
    to: posterEmail,
    message: {
      subject: "Neue Anfrage zu Ihrer Kapazität – Capacify",
      html:
        `<p>Ein ${verified}Bauunternehmen aus ${city} interessiert sich für Ihre Kapazität.</p>` +
        (req.message ? `<p><em>„${req.message}“</em></p>` : "") +
        `<p>Öffnen Sie „Erhaltene Anfragen“, um zu antworten:</p>` +
        `<p><a href="https://capacify-mvp.web.app/">In Capacify öffnen</a></p>`,
    },
  });
});
```

Notes:
- No app code changes are needed to enable this — the function reads data the app already
  writes (`contact_requests`, `capacityOwners`, `users.notifyByEmail`).
- To also email the **requester on accept** (poster → requester direction), that one *is*
  client-feasible (the poster can read the requester's public company), but the function
  approach keeps both directions consistent and off the client. Add an
  `onDocumentUpdated` handler that fires when `status` flips to `granted`.
