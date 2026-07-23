# Capacify

Capacify is a **Flutter** app (mobile + Flutter web) backed by **Firebase**
(Auth, Firestore, Storage, Cloud Functions, App Check). There is no Next.js
here — treat Dart/Flutter as the source of truth.

## Stack
- **UI / app**: Flutter, Dart (`lib/`). State via `flutter_riverpod`,
  localization in `lib/core/localization/app_localizations.dart`.
- **Routing**: `go_router`, configured in `lib/core/router/app_router.dart`
  (`MaterialApp.router`). Public pages, the signed-in shell's section
  (`/app/favoriten`), and the post/company deep links all have real URLs.
  Navigation *inside* a section is still plain `Navigator` — see the scope note
  at the top of that file before adding routes.
- **Backend**: Firebase project `capacify-mvp`. Firestore rules in
  `firestore.rules`, Storage rules in `storage.rules`, Cloud Functions in
  `functions/`.
- **Web build output**: `flutter build web` → `build/web`.
- **Fonts**: Inter and Archivo are **bundled assets** (`assets/fonts/`,
  declared in `pubspec.yaml`). Deliberately not `google_fonts` — fetching them
  from fonts.gstatic.com at runtime blocked first paint and handed the
  visitor's IP to Google pre-consent. Don't reintroduce the package; the CSP in
  `firebase.json` no longer allows either Google font host.
- **Accessibility**: `main.dart` calls `SemanticsBinding.instance.ensureSemantics()`
  at boot, so the semantics tree exists from the first frame instead of waiting
  for web's hidden "Enable accessibility" button. Anything tappable needs a
  focus node and a button role — use `InkWell`, or `HoverLift` /
  `PressableButton` from `lib/shared/widgets/interactions.dart`, never a bare
  `GestureDetector`.
- **Email**: see `docs/email-delivery.md`. `SMTP_URL` **and** `MAIL_FROM` are
  both required before anything sends; the two engagement emails need
  `UNSUB_SECRET` for their one-click unsubscribe headers.

## Checks
- `flutter analyze --no-fatal-infos` and `flutter test` — both must stay green;
  warnings and errors fail CI, infos don't (yet).
- `node tool/check_import_case.js` — catches imports whose case doesn't match
  what git tracks (fine on Windows, fatal on Linux) and imports of files that
  were never `git add`ed.
- `cd firestore-tests && npm ci && npm run test:emulator` — the `firestore.rules`
  suite against the Firestore emulator. Needs a JDK 17+ on PATH.
- All three run on every push/PR via `.github/workflows/ci.yml`, which also
  builds web on Linux.

## Deploy
Deployment is **Firebase Hosting**, not Vercel — `firebase.json` points
Hosting at `build/web`. Currently deployed by hand:
`flutter build web --release && firebase deploy --only hosting,functions`.
Hosting rewrites `**` → `/index.html`, which is what makes the go_router paths
survive a hard refresh.
