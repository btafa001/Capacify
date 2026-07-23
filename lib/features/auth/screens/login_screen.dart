import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/capacify_logo.dart';
import 'forgot_password_screen.dart';
import '../../onboarding/company_gate.dart';
import '../../../core/services/analytics_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('Login');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authServiceProvider).loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      AnalyticsService.logEvent('login', parameters: {'method': 'email'});
      // Navigate to the dashboard directly rather than popping back to "the
      // first route" and relying on main.dart's authStateProvider-driven
      // home gate to have already swapped to it — that gate only rebuilds
      // when the auth stream emits, which can land slightly after (rather
      // than before) this code runs, especially for the popup-based Google
      // flow. Racing it caused intermittent landings back on the page this
      // screen was pushed from instead of the dashboard.
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CompanyGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final credential =
          await ref.read(authServiceProvider).signInWithGoogle();
      if (credential == null) return; // user closed popup
      AnalyticsService.logEvent('login', parameters: {'method': 'google'});
      // Navigate to the dashboard directly rather than popping back to "the
      // first route" and relying on main.dart's authStateProvider-driven
      // home gate to have already swapped to it — that gate only rebuilds
      // when the auth stream emits, which can land slightly after (rather
      // than before) this code runs, especially for the popup-based Google
      // flow. Racing it caused intermittent landings back on the page this
      // screen was pushed from instead of the dashboard.
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CompanyGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // go, not push: the wordmark means "take me home", and stacking the landing
  // page on top of the login page it was opened from is not that.
  void _toLanding() => context.go(Routes.landing);

  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final credential =
          await ref.read(authServiceProvider).signInWithApple();
      if (credential == null) return; // user closed popup
      AnalyticsService.logEvent('login', parameters: {'method': 'apple'});
      // Navigate to the dashboard directly rather than popping back to "the
      // first route" and relying on main.dart's authStateProvider-driven
      // home gate to have already swapped to it — that gate only rebuilds
      // when the auth stream emits, which can land slightly after (rather
      // than before) this code runs, especially for the popup-based Google
      // flow. Racing it caused intermittent landings back on the page this
      // screen was pushed from instead of the dashboard.
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CompanyGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width > 900;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          _login();
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Row(
          children: [
            if (isWide)
              Expanded(
                flex: 3,
                child: Container(
                  color: c.surfaceVariant,
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _toLanding,
                        child: CapacifyWordmark(symbolSize: 66, fontSize: 38, textColor: c.textPrimary),
                      ),
                      const SizedBox(height: 64),
                      Text(l.loginSloganLine1, style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.1, letterSpacing: -1)),
                      Text(l.loginSloganLine2, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1.1, letterSpacing: -1)),
                      const SizedBox(height: 40),
                      Text(l.loginSloganSub, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textSecondary, height: 1.3)),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.only(left: 20),
                        decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.primary, width: 4))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.loginQuote1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: c.textSecondary, height: 1.4)),
                            Text(l.loginQuote2, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: c.textSecondary, height: 1.4)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(l.loginLiveBadge, style: const TextStyle(fontSize: 13, color: AppColors.live, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 40 : 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isWide)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: _toLanding,
                                child: CapacifyWordmark(symbolSize: 70, fontSize: 40, textColor: c.textPrimary),
                              ),
                            ),
                          Text(l.loginTitle, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5)),
                          const SizedBox(height: 6),
                          Text(l.loginWelcome, style: TextStyle(fontSize: 16, color: c.textSecondary)),
                          SizedBox(height: isWide ? 36 : 16),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.error.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 14))),
                                ],
                              ),
                            ),
                            SizedBox(height: isWide ? 20 : 14),
                          ],
                          CustomTextField(
                            label: l.emailLabel,
                            hint: l.emailHint,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => Validators.email(v, l),
                          ),
                          SizedBox(height: isWide ? 20 : 14),
                          CustomTextField(
                            label: l.passwordLabel,
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: c.textSecondary,
                              ),
                              tooltip: _obscurePassword ? l.showPasswordTooltip : l.hidePasswordTooltip,
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) => v == null || v.isEmpty ? l.required : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                              child: Text(l.forgotPassword),
                            ),
                          ),
                          SizedBox(height: isWide ? 16 : 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                elevation: 6,
                                shadowColor: AppColors.primary.withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                  : Text(l.loginButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ),
                          ),
                          SizedBox(height: isWide ? 24 : 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l.noAccount, style: TextStyle(color: c.textSecondary, fontSize: 15)),
                              TextButton(
                                onPressed: () => context.push(Routes.register),
                                child: Text(l.registerLink),
                              ),
                            ],
                          ),

                          SizedBox(height: isWide ? 28 : 12),

                          // ── Social divider ──
                          Row(
                            children: [
                              Expanded(child: Divider(color: c.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(l.orDivider, style: TextStyle(fontSize: 13, color: c.textTertiary)),
                              ),
                              Expanded(child: Divider(color: c.border)),
                            ],
                          ),

                          SizedBox(height: isWide ? 20 : 12),

                          // ── Google ──
                          _SocialButton(
                            icon: const FaIcon(FontAwesomeIcons.google, size: 17, color: Color(0xFF4285F4)),
                            label: l.continueWithGoogle,
                            onTap: _isLoading ? null : _signInWithGoogle,
                          ),

                          // ── Apple ── (hidden until the provider is enabled
                          // in Firebase — see kAppleSignInEnabled. The leading
                          // spacer is inside the guard so Google isn't left
                          // with a dangling gap beneath it.)
                          if (kAppleSignInEnabled) ...[
                            SizedBox(height: isWide ? 12 : 8),
                            _SocialButton(
                              icon: FaIcon(FontAwesomeIcons.apple, size: 18, color: c.textPrimary),
                              label: l.continueWithApple,
                              onTap: _isLoading ? null : _signInWithApple,
                            ),
                          ],

                          if (isWide) const SizedBox(height: 8),
                        ],
                      ),
                    ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Social Button ────────────────────────────────────────────────────────────

class _SocialButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  const _SocialButton({required this.icon, required this.label, this.onTap});
  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final disabled = widget.onTap == null;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _hover && !disabled
                ? c.border.withOpacity(0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: disabled
                  ? c.border.withOpacity(0.4)
                  : _hover
                      ? c.textSecondary.withOpacity(0.5)
                      : c.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? c.textTertiary
                      : c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
