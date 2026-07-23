import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/analytics_service.dart';
import '../services/auth_provider.dart';
import '../../features/landing/screens/landing_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/pricing/screens/pricing_screen.dart';
import '../../features/landing/screens/about_screen.dart';
import '../../features/legal/screens/agb_screen.dart';
import '../../features/legal/screens/datenschutz_screen.dart';
import '../../features/legal/screens/impressum_screen.dart';
import '../../features/onboarding/company_gate.dart';
import 'deep_link_page.dart';

/// URL routing for the web app (H4).
///
/// The app was a single `MaterialApp(home:)` — go_router sat in pubspec.yaml
/// unused and AGENTS.md claimed it was the router. That cost real things every
/// day: a browser refresh dumped the user back on the feed with all context
/// lost, nothing was bookmarkable or shareable except `?capacity=<id>`, browser
/// back was best-effort, and only the landing page could ever be indexed.
///
/// Scope of this pass, deliberately:
///  * Every PUBLIC page has a real URL — those are the pages that get linked,
///    indexed and pasted into emails (`/preise`, `/agb`, …).
///  * The signed-in shell carries its section in the path (`/app/favoriten`),
///    so refresh and browser back keep the user where they were, and a
///    colleague can be sent straight to a section.
///  * Deep links for a single post (`/kapazitaet/:id`) and a single company
///    (`/unternehmen/:id`), with the legacy `?capacity=<id>` link shape still
///    honoured — those links are already out in the wild.
///
/// What is NOT converted yet: navigation *within* a section (pushed detail
/// pages, the composer dialog, the mobile drawer's pushed routes) still uses
/// Navigator directly. Those are modal/leaf views where a URL buys little, and
/// converting them means restructuring DashboardScreen around a ShellRoute —
/// worth doing, but not worth bundling into the change that makes URLs exist
/// at all.
///
/// Hosting already rewrites `**` → `/index.html` (firebase.json), so every path
/// below survives a hard refresh in production.

/// Sections of the signed-in shell that are addressable.
///
/// The slug is the URL segment and is part of the app's public surface once
/// people bookmark it — treat these as stable. German, matching the UI.
enum AppSection {
  feed('feed'),
  companies('unternehmen'),
  listings('inserate'),
  requests('anfragen'),
  contacts('kontakte'),
  messages('nachrichten'),
  favorites('favoriten'),
  admin('admin');

  const AppSection(this.slug);
  final String slug;

  static AppSection fromSlug(String? slug) => AppSection.values.firstWhere(
        (s) => s.slug == slug,
        orElse: () => AppSection.feed,
      );

  /// The location this section lives at. The feed is the bare shell root
  /// rather than `/app/feed`, so the everyday URL stays short.
  String get location => this == AppSection.feed ? '/app' : '/app/$slug';
}

/// Path constants, so a rename is a compile error rather than a dead link.
class Routes {
  static const landing = '/';
  static const login = '/login';
  static const register = '/registrieren';
  static const pricing = '/preise';
  static const about = '/ueber-uns';
  static const agb = '/agb';
  static const privacy = '/datenschutz';
  static const imprint = '/impressum';
  static const app = '/app';
  static const capacity = '/kapazitaet'; // + /:id
  static const company = '/unternehmen'; // + /:id

  /// Paths only reachable while signed in.
  static bool isProtected(String location) => location.startsWith(app);

  /// Paths a signed-in user has no business sitting on.
  static bool isSignedOutOnly(String location) =>
      location == landing || location == login || location == register;
}

/// The Listenable go_router wants in order to re-run `redirect`.
///
/// Driven by `ref.listen(authStateProvider)` rather than by a second
/// subscription to `FirebaseAuth.authStateChanges` — that distinction is the
/// whole bug it fixes. With its own subscription, the notification could reach
/// the router BEFORE authStateProvider had processed the same event, so
/// `redirect` re-ran, still saw AsyncLoading, declined to redirect, and was
/// never called again (the auth stream only emits once on a cold load). Net
/// effect: a signed-out visitor could sit on /app indefinitely. Listening to
/// the provider guarantees its value is already updated when we notify.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Root navigator, exposed because a couple of flows need a context that
/// outlives the widget they were triggered from (see create_capacity_screen's
/// post-submit snackbar). Previously lived in main.dart.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  // fireImmediately also starts the auth stream, so "loading" actually resolves
  // rather than waiting for the first widget to watch it.
  ref.listen(authStateProvider, (_, __) => refresh.ping(), fireImmediately: true);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.landing,
    refreshListenable: refresh,
    // Screen-view tracking moved off MaterialApp.navigatorObservers, which
    // MaterialApp.router doesn't consult — the router owns the Navigator now.
    observers: [AnalyticsService.observer],
    redirect: (context, state) {
      // Links already shared in the wild use the pre-routing shape
      // `https://…/?capacity=<id>`. Translate rather than break them; the app
      // now emits `/kapazitaet/<id>` (see the share action in
      // live_capacity_feed_screen).
      final legacyCapacityId = state.uri.queryParameters['capacity'];
      if (legacyCapacityId != null && legacyCapacityId.isNotEmpty) {
        return '${Routes.capacity}/$legacyCapacityId';
      }

      final auth = ref.read(authStateProvider);
      // Auth hasn't resolved yet on a cold load. Redirecting on a *guess* here
      // is the classic version of this bug: a signed-in user hard-refreshing
      // /app gets bounced to /login for the split second before Firebase
      // restores the session. Send nobody anywhere until we actually know —
      // CompanyGate shows a spinner in the meantime.
      if (auth.isLoading) return null;
      final signedIn = auth.value != null;
      final location = state.matchedLocation;

      if (!signedIn && Routes.isProtected(location)) return Routes.login;
      if (signedIn && Routes.isSignedOutOnly(location)) return Routes.app;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.landing,
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.pricing,
        builder: (_, __) => const PricingScreen(),
      ),
      GoRoute(
        path: Routes.about,
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: Routes.agb,
        builder: (_, __) => const AGBScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (_, __) => const DatenschutzScreen(),
      ),
      GoRoute(
        path: Routes.imprint,
        builder: (_, __) => const ImpressumScreen(),
      ),

      // ── The signed-in shell ──
      // `/app` and `/app/:section` deliberately produce the SAME page key, so
      // moving between sections updates the URL without remounting the shell.
      // A remount would re-run DashboardScreen's _loadUserData (and every feed
      // listener under it) on each sidebar click — the URL is meant to be free.
      GoRoute(
        path: Routes.app,
        pageBuilder: (_, __) => const NoTransitionPage(
          key: _shellKey,
          child: CompanyGate(),
        ),
        routes: [
          GoRoute(
            path: ':section',
            pageBuilder: (_, state) => NoTransitionPage(
              key: _shellKey,
              child: CompanyGate(
                section: AppSection.fromSlug(state.pathParameters['section']),
              ),
            ),
          ),
        ],
      ),

      // ── Deep links ──
      // Both render the shell with the target opened on top of it, so a
      // shared link lands somewhere the visitor can actually keep using —
      // not on an orphan page with no way back into the app.
      GoRoute(
        path: '${Routes.capacity}/:id',
        builder: (_, state) =>
            DeepLinkPage(capacityId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '${Routes.company}/:id',
        builder: (_, state) =>
            DeepLinkPage(companyId: state.pathParameters['id']),
      ),
    ],
    errorBuilder: (_, __) => const LandingScreen(),
  );
});

const _shellKey = ValueKey<String>('app-shell');
