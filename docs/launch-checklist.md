# Pre-launch checklist — operational items

These are the pre-launch items that are **not code changes in this repo** — they
live in the Firebase/GCP console, in gcloud, or are product decisions to record.
Tracked here so they don't get lost. Project: `capacify-mvp`.

See also the code-level pre-launch items already tracked in the auto-memory
(`project_prelaunch_audit_2026-07`, `project_legal_review_pending`,
`project_identity_ansprechpartner`) — this file is only the ops/console layer.

---

## M4 — Admin account hardening

### a) Enable MFA on the founder / admin account  *(console — do before launch)*
The `isAdmin` flag grants unrestricted write over every user, company and
rating. That account must not be protected by a password alone.

- **If the admin signs in with Google:** turn on 2-Step Verification (TOTP or a
  security key) on that Google account — https://myaccount.google.com/security.
  This is the fastest win and needs no project changes.
- **If the admin uses email/password:** enable TOTP MFA in
  **Firebase Console → Authentication → Settings → Multi-factor authentication**,
  then enrol the founder account. Note: TOTP MFA requires the project to be on
  **Firebase Authentication with Identity Platform** (free tier is fine at this
  scale) — you may be prompted to upgrade. The client code does not need to
  change to protect the admin's *own* sign-in.

### b) Admin action audit log  *(optional follow-up — code, not yet done)*
`suspend / unsuspend / approveVerification / revokeVerification / approveRating /
rejectRating / deleteRatingAndRecompute / approveFlagged*` in
`lib/core/services/admin_service.dart` are currently **unattributed** — nothing
records who did what, when.

Recommended lightweight approach (deferred out of the audit change-set on
purpose — say the word and it can be implemented):
- New `adminAuditLog` collection: `{ actorUid, action, targetType, targetId,
  details, at }`. Rules: `create`/`read` if `isAdmin()`, `update`/`delete: false`
  (append-only), shape-pinned — same posture as the new `clientErrors` sink.
- A `_logAdminAction(...)` helper in `AdminService`, called from each mutation.
- Caveat: a client-side log written by the admin is only as trustworthy as the
  admin (they could bypass it). For a tamper-resistant trail, drive it from
  Cloud Functions `onDocumentUpdated` triggers on `companies`/`companyRatings`
  instead. Client-side is the "lightweight" version the audit suggested; the
  trigger version is the airtight one.

---

## M8 — Backups  *(gcloud/console — do before launch)*
No backups exist today. One bad admin-script loop and there's no recovery point.

1. **Point-in-time recovery** (continuous, 7-day window):
   ```bash
   gcloud firestore databases update "(default)" \
     --project=capacify-mvp --enable-pit-recovery
   ```
2. **Scheduled daily backups** (managed, retained 7 days):
   ```bash
   gcloud firestore backups schedules create \
     --project=capacify-mvp --database="(default)" \
     --recurrence=daily --retention=7d
   ```
   (Add a weekly schedule with longer retention if you want a deeper history.)
3. **Optional — periodic export to a GCS bucket** you control, for off-Firestore
   copies. Create a dedicated bucket (NOT the app's `firebasestorage.app` bucket)
   and export on a Cloud Scheduler cron:
   ```bash
   gsutil mb -p capacify-mvp -l europe-west3 gs://capacify-mvp-backups
   gcloud firestore export gs://capacify-mvp-backups \
     --project=capacify-mvp
   ```
   Confirm the App Engine / Firestore service account has
   `roles/datastore.importExportAdmin` and write access to the bucket.

Verify at least one restore path works before relying on it.

---

## M10 — Promote CSP from Report-Only to enforced  *(one-line change — after verification)*
The Content-Security-Policy in `firebase.json` ships as
`Content-Security-Policy-Report-Only` on purpose (a single missed endpoint under
an enforced policy is a total-lockout failure class — same as the past App Check
incidents). The full rationale and promotion steps are in the `"//"` comment
above the header block in `firebase.json`.

**Before launch:** with the site deployed, open DevTools and confirm the console
shows **no CSP violation reports** across: email login, Google/Apple popup,
reCAPTCHA/App Check, Firestore reads, logo load from Storage, FCM, Analytics.
Then promote by renaming the header key:

- `firebase.json` → `Content-Security-Policy-Report-Only` → **`Content-Security-Policy`**
- `firebase deploy --only hosting`

Leaving it in Report-Only forever defeats the point — this is the reminder not to.

---

## M12 — Language policy  *(decision — record & confirm)*
The UI is DE/EN, but the **service-layer error strings**
(`lib/core/services/auth_service.dart` `_handleAuthException`, etc.) and **all
transactional emails** (`functions/` + `docs/email-delivery.md`) are **German-only**.

**Recommended decision (per the audit): declare EN "best effort" for the Hamburg
launch.** German is the product language; English is a convenience for the UI
chrome only. Revisit (translate service errors + add EN email variants) when
expanding beyond the German-speaking market.

→ **Confirm or override this.** If you'd rather fix it now, the work is: an EN
map for `_handleAuthException` codes, and EN variants of the email templates
keyed off the recipient's stored locale.
