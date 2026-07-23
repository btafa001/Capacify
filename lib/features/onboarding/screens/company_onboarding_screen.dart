import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/capacify_logo.dart';

/// Closes the two gaps the Google/Apple sign-up path used to leave open (H2):
///
///  1. **No consent.** `_signUpWithGoogle()` never checked the AGB/
///     Datenschutz box — that check only ever existed on the email form — so
///     the highest-converting button on the page created accounts with no
///     recorded acceptance at all.
///  2. **No company.** OAuth sign-in creates a `users` doc and nothing else,
///     while every meaningful action in the app (posting, contacting,
///     Getting-Started card, "Meine Inserate") needs a `companies/{uid}` doc.
///     The user landed on a dashboard whose onboarding card is hidden exactly
///     when they need it (it renders only when `_userCompany != null`) and got
///     a "create a company first" snackbar with nowhere to go.
///
/// So this screen is shown INSTEAD of the dashboard whenever a signed-in
/// account has no company yet (see CompanyGate) — not only right after signup.
/// That deliberately also rescues every account already stranded in that state
/// by the old flow: they get the interstitial on their next visit.
///
/// Kept to exactly two inputs on purpose. Everything else about a company
/// profile is optional at this point and reachable later from
/// "Unternehmensprofil"; the funnel's job here is to end with a usable account,
/// not a complete one.
class CompanyOnboardingScreen extends ConsumerStatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  ConsumerState<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState
    extends ConsumerState<CompanyOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();

  bool _isLoading = false;
  bool _consentChecked = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('CompanyOnboarding');
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      setState(() => _errorMessage = l.consentError);
      return;
    }
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final company = CompanyModel(
        // Doc id is the owner's uid by convention everywhere else in the app
        // (CompanyService, firestore.rules' companies/{companyId} ==
        // request.auth.uid check) — keep it.
        id: user.uid,
        ownerId: user.uid,
        name: _companyNameController.text.trim(),
        description: '',
        website: '',
        // The OAuth provider already gave us a verified address; using it as
        // the company contact means the profile isn't contactless on day one.
        email: user.email ?? '',
        phone: '',
        address: '',
        city: 'Hamburg',
        postalCode: '',
        country: 'Deutschland',
        employees: '1-5',
        trades: const [],
        services: const [],
        logoUrl: '',
        // Always 'none' at creation — firestore.rules rejects anything else,
        // and 'pending' is reachable only through the verifyMyCompany Cloud
        // Function after a real VIES check.
        verificationStatus: 'none',
        // Must equal the caller's own token claim; Google/Apple accounts are
        // pre-verified by the provider, so this is normally true here and the
        // company is directory-eligible immediately.
        emailVerified: user.emailVerified,
        contentFlagged: false,
        // Same invite attribution the email signup records (?ref=<companyId>).
        referredBy: ref.read(authServiceProvider).referrerFromUrl(
              excludeUid: user.uid,
            ),
      );
      await ref.read(companyServiceProvider).createCompany(company);
      // Recorded on the user doc, not just held in this widget's state: the
      // email path's checkbox left no evidence either, and an AGB acceptance
      // you can't produce later is not much of an acceptance.
      await ref.read(authServiceProvider).recordLegalConsent(user.uid);

      AnalyticsService.logEvent('onboarding_company_created');
      if (!mounted) return;
      // The gate watches this provider — invalidating it re-reads the company
      // and swaps this screen for the dashboard. No Navigator push, so there's
      // no back button leading to a half-finished onboarding.
      ref.invalidate(myCompanyProvider(user.uid));
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = l.onboardingCreateError);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CapacifyWordmark(
                      symbolSize: 62,
                      fontSize: 36,
                      textColor: c.textPrimary,
                    ),
                    const SizedBox(height: 36),
                    Text(
                      l.onboardingTitle,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.onboardingSubtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: c.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (user?.email != null && user!.email!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.account_circle_outlined,
                              size: 16, color: c.textTertiary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${l.onboardingSignedInAs} ${user.email}',
                              style: TextStyle(
                                  fontSize: 13, color: c.textTertiary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    CustomTextField(
                      label: l.companyNameLabel,
                      hint: l.companyNameHint,
                      controller: _companyNameController,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l.required : null,
                    ),
                    const SizedBox(height: 18),

                    // ── Consent (identical wording to the email register form) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _consentChecked,
                            onChanged: (v) =>
                                setState(() => _consentChecked = v ?? false),
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            side:
                                BorderSide(color: c.textSecondary, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              children: [
                                Text(l.consentPrefix,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: c.textSecondary,
                                        height: 1.5)),
                                GestureDetector(
                                  onTap: () => context.push(Routes.agb),
                                  child: const Text('AGB',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          height: 1.5,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.primary)),
                                ),
                                Text(l.consentMiddle,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: c.textSecondary,
                                        height: 1.5)),
                                GestureDetector(
                                  onTap: () => context.push(Routes.privacy),
                                  child: const Text('Datenschutzerklärung',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          height: 1.5,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.primary)),
                                ),
                                Text(l.consentSuffix,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: c.textSecondary,
                                        height: 1.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _submit(l),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 6,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text(l.onboardingContinue,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      l.onboardingLater,
                      style: TextStyle(
                          fontSize: 12, color: c.textTertiary, height: 1.5),
                    ),
                    const SizedBox(height: 8),

                    Center(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => ref.read(authServiceProvider).signOut(),
                        child: Text(l.onboardingWrongAccount),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
