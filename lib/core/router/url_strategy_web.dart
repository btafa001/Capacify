import 'package:flutter_web_plugins/url_strategy.dart';

/// Switches Flutter web from its default HASH strategy (`/#/preise`) to real
/// paths (`/preise`).
///
/// Without this the routes in app_router.dart are effectively dead: the browser
/// shows `/preise`, but Flutter reports the location as `/` because it only
/// ever reads the fragment — so go_router matches the landing route, no
/// redirect fires, and nothing is bookmarkable. It is genuinely one line
/// between "we have URL routing" and "we don't".
///
/// Safe here because Firebase Hosting already rewrites `**` → `/index.html`
/// (firebase.json), so a hard refresh on `/preise` still serves the app rather
/// than 404ing — which is exactly the trade the hash strategy exists to avoid
/// on servers that lack such a rewrite.
void configureUrlStrategy() => usePathUrlStrategy();
