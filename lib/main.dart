import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/services/analytics_service.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/consent_banner.dart';
import 'core/services/auth_provider.dart';
import 'core/services/theme_provider.dart';
import 'core/services/capacity_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'features/landing/screens/landing_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/opportunities/screens/capacity_detail_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

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

  // Preload every Inter/Archivo weight actually used by the theme and the
  // landing page before first paint, so nothing flashes the fallback system
  // font in for a moment on load. Each (family, weight) pair is a distinct
  // downloadable file to Google Fonts — preloading just the default weight
  // isn't enough since interTextTheme() and the headline text use w600-w900.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check + font preload run in parallel after Firebase is up. App Check
  // attests requests come from the real app (reCAPTCHA v3) before Firestore/
  // Auth accept them — the defense that makes the rules-enforced paywall and
  // anti-spam actually hold against scripted access. Activation is wrapped so
  // a transient App Check failure never blanks the app on load.
  await Future.wait([
    _activateAppCheck(),
    GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.inter(fontWeight: FontWeight.w900),
      GoogleFonts.archivo(fontWeight: FontWeight.w900),
    ]),
  ]);

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSharedCapacityIfAny());
  }

  // Resolves a shared post link (?capacity=<id> in the URL) to the actual
  // post, shown as the same popup used from My Listings/Favorites — runs
  // once on load, on top of whatever home screen auth state resolves to,
  // so a shared link works whether or not the visitor is signed in.
  Future<void> _openSharedCapacityIfAny() async {
    final capacityId = Uri.base.queryParameters['capacity'];
    if (capacityId == null || capacityId.isEmpty) return;
    final capacity = await ref.read(capacityServiceProvider).getCapacityById(capacityId);
    final context = navigatorKey.currentContext;
    if (capacity == null || context == null || !context.mounted) return;
    showCapacityDetailDialog(context, capacity);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Capacify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('de'), Locale('en')],
      navigatorObservers: [AnalyticsService.observer],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ConsentGate overlays the GDPR cookie banner until the visitor decides;
      // analytics stays off until then (AnalyticsService is gated on consent).
      home: ConsentGate(
        child: authState.when(
          data: (user) {
            if (user != null) return const DashboardScreen();
            return const LandingScreen();
          },
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (_, __) => const LandingScreen(),
        ),
      ),
    );
  }
}
