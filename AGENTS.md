# Capacify

Capacify is a **Flutter** app (mobile + Flutter web) backed by **Firebase**
(Auth, Firestore, Storage, Cloud Functions, App Check). Despite some tooling
config that may be present, this is not a Next.js project — treat Dart/Flutter
as the source of truth.

## Stack
- **UI / app**: Flutter, Dart (`lib/`). State via `flutter_riverpod`, routing
  via `go_router`, localization in `lib/core/localization/app_localizations.dart`.
- **Backend**: Firebase project `capacify-mvp`. Firestore rules in
  `firestore.rules`, Storage rules in `storage.rules`, Cloud Functions in
  `functions/`.
- **Web build output**: `flutter build web` → `build/web`.

## Deploy
Deployment is **Firebase Hosting**, not Vercel. `firebase.json` points Hosting
at `build/web`. CI in `.github/workflows/deploy.yml` builds Flutter web and
runs `firebase deploy --only hosting,storage` on push to `main` (needs the
`FIREBASE_SERVICE_ACCOUNT` repo secret).
