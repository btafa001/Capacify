import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/router/url_strategy_stub.dart'
    if (dart.library.js_interop) 'core/router/url_strategy_web.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/consent_banner.dart';
import 'core/services/theme_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';

// Non-fatal App Check activation: if reCAPTCHA can't init (network, blocked
// script, etc.) the app still loads — enforcement is toggled server-side and
// isn't enabled until tokens are confirmed flowing, so failing open here is safe.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(kAppCheckRecaptchaSiteKey),
    );
  } catch (e) {
    // Log rather than silently swallow. A bare `catch (_) {}` here hid a total
    // App Check activation failure during the enforcement rollout — with
    // enforcement on, no token means every Firestore/Auth request is rejected
    // (a full login lockout), so this failure must never be invisible again.
    debugPrint('App Check activation failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Build the semantics tree unconditionally, for the whole life of the app.
  //
  // Flutter only produces semantics when some client asks for it. On web that
  // client is a hidden "Enable accessibility" button the visitor has to find
  // and press first — so an audit of the live site saw an accessibility tree
  // containing exactly that one node and nothing else: no headings, no labels,
  // no buttons. A screen-reader or keyboard-only user had no product at all.
  // Holding this handle forever keeps the tree populated from the first frame.
  // (Deliberately never disposed — dropping the last handle switches semantics
  // back off. The cost is the tree being maintained even for users who don't
  // need it, which is the correct trade for an EAA-scope B2B product.)
  SemanticsBinding.instance.ensureSemantics();

  // Real paths instead of `/#/…`. Must run before the first frame — see
  // core/router/url_strategy_web.dart for why the routes don't work without it.
  configureUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check attests requests come from the real app (reCAPTCHA v3) before
  // Firestore/Auth accept them — the defense that makes the rules-enforced
  // paywall and anti-spam actually hold against scripted access. Activation is
  // wrapped so a transient App Check failure never blanks the app on load.
  //
  // Nothing else blocks runApp any more: Inter/Archivo used to be downloaded
  // from fonts.gstatic.com here (five files, awaited) — they're bundled assets
  // now, so there is no font round-trip to wait on and no visitor IP handed to
  // Google before the consent banner is answered.
  await _activateAppCheck();

  runApp(
    const ProviderScope(
      child: CapacifyApp(),
    ),
  );
}

class CapacifyApp extends ConsumerStatefulWidget {
  const CapacifyApp({super.key});

  @override
  ConsumerState<CapacifyApp> createState() => _CapacifyAppState();
}

class _CapacifyAppState extends ConsumerState<CapacifyApp> {
  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // MaterialApp.router, not MaterialApp(home:) — the app now has real URLs
    // (see core/router/app_router.dart). Shared-link handling that used to live
    // here as a one-shot ?capacity= reader is a route now (/kapazitaet/:id),
    // with the old query-parameter form redirected to it, so a refresh or a
    // second shared link works the same as the first.
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      title: 'Capacify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ConsentGate overlays the GDPR cookie banner until the visitor decides;
      // analytics stays off until then (AnalyticsService is gated on consent).
      // As a builder rather than a wrapper around `home`, so it sits above
      // every route instead of only the first one.
      builder: (context, child) => ConsentGate(child: child ?? const SizedBox()),
    );
  }
}
