# Capacify

Capacify is a **Flutter** app (mobile + Flutter web) backed by **Firebase**
(Auth, Firestore, Storage, Cloud Functions, App Check). There is no Next.js
here — treat Dart/Flutter as the source of truth.

## Stack
- **UI / app**: Flutter, Dart (`lib/`). State via `flutter_riverpod`, routing
  via `go_router`, localization in `lib/core/localization/app_localizations.dart`.
- **Backend**: Firebase project `capacify-mvp`. Firestore rules in
  `firestore.rules`, Storage rules in `storage.rules`, Cloud Functions in
  `functions/`.
- **Web build output**: `flutter build web` → `build/web`.

## Deploy
Deployment is **Firebase Hosting**, not Vercel — `firebase.json` points
Hosting at `build/web`. Currently deployed by hand:
`flutter build web --release && firebase deploy --only hosting,functions`.
