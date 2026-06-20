import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_provider.dart';
import 'core/services/theme_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'features/landing/screens/landing_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: CapacifyApp(),
    ),
  );
}

class CapacifyApp extends ConsumerWidget {
  const CapacifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
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
      home: authState.when(
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
    );
  }
}
