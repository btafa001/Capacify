import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/company_provider.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../landing/screens/landing_screen.dart';
import 'screens/company_onboarding_screen.dart';

/// The single entry point for a signed-in session.
///
/// Every path that used to jump straight to `DashboardScreen` goes through
/// here instead (main.dart's auth gate, and the `pushAndRemoveUntil` calls in
/// the login/register screens, which bypass main.dart entirely). That matters
/// because the dashboard is useless without a `companies/{uid}` doc: posting
/// and contacting both refuse, "Meine Inserate" shows a snackbar, and the
/// Getting-Started card — the one thing that would explain the situation — is
/// itself hidden behind `_userCompany != null`.
///
/// Google/Apple sign-in creates a user doc and no company (see
/// AuthService.signInWithGoogle), so before this gate existed every OAuth
/// signup landed in exactly that dead end. Now a missing company means
/// onboarding, wherever the account came from and however long ago — accounts
/// already stranded by the old flow get the interstitial on their next visit.
class CompanyGate extends ConsumerWidget {
  const CompanyGate({super.key, this.section = AppSection.feed});

  /// Which shell section to open — comes from the URL (`/app/favoriten`), so
  /// a refresh or a shared link keeps the user where they were.
  final AppSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    // Firebase restores a persisted session asynchronously. Treating "not
    // resolved yet" as "signed out" would flash the landing page at every
    // returning user on every hard refresh.
    if (auth.isLoading) return const _GateSpinner();
    final user = auth.value;
    if (user == null) return const LandingScreen();

    return ref.watch(myCompanyProvider(user.uid)).when(
          data: (company) => company == null
              ? const CompanyOnboardingScreen()
              : DashboardScreen(section: section),
          loading: () => const _GateSpinner(),
          // Fail OPEN to the dashboard. A transient read failure (offline, a
          // rules hiccup) must never drop an established customer into
          // onboarding — they'd be invited to create a second company profile
          // over the top of their real one. Onboarding is shown only on a
          // confirmed "no company", never on "couldn't tell".
          error: (_, __) => DashboardScreen(section: section),
        );
  }
}

class _GateSpinner extends StatelessWidget {
  const _GateSpinner();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
