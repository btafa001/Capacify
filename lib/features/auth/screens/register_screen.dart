import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/form_draft_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/capacify_logo.dart';
import '../../legal/screens/agb_screen.dart';
import '../../legal/screens/datenschutz_screen.dart';
import '../../../core/services/analytics_service.dart';
import '../../landing/screens/landing_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController    = TextEditingController();
  final _lastNameController     = TextEditingController();
  final _emailController        = TextEditingController();
  final _passwordController     = TextEditingController();
  final _companyNameController  = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _consentChecked = false;
  String? _errorMessage;
  int _passwordStrength = 0;

  // Draft-save (#4 persona finding: interrupted mid-registration loses
  // everything typed). Password is deliberately NEVER persisted. Periodic
  // rather than per-keystroke — covers backgrounding/interruption without a
  // debounce timer on every field.
  static const _draftKey = 'draft_register';
  Timer? _draftTimer;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('Register');
    _passwordController.addListener(() {
      if (mounted) _checkPasswordStrength(_passwordController.text);
    });
    _restoreDraft();
    _draftTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraft());
  }

  void _restoreDraft() {
    final draft = FormDraftService.load(_draftKey);
    if (draft == null) return;
    _firstNameController.text = draft['firstName'] as String? ?? '';
    _lastNameController.text = draft['lastName'] as String? ?? '';
    _emailController.text = draft['email'] as String? ?? '';
    _companyNameController.text = draft['companyName'] as String? ?? '';
  }

  void _saveDraft() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final companyName = _companyNameController.text.trim();
    if (firstName.isEmpty && lastName.isEmpty && email.isEmpty && companyName.isEmpty) return;
    FormDraftService.save(_draftKey, {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'companyName': companyName,
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (!_registered) _saveDraft();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    setState(() => _passwordStrength = strength);
  }

  Color get _strengthColor {
    switch (_passwordStrength) {
      case 1: return AppColors.error;
      case 2: return AppColors.warning;
      case 3: return AppColors.live;
      default: return Colors.grey;
    }
  }

  String _strengthLabel(AppLocalizations l) {
    switch (_passwordStrength) {
      case 1: return l.passwordWeak;
      case 2: return l.passwordMedium;
      case 3: return l.passwordStrong;
      default: return '';
    }
  }

  void _toLanding() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LandingScreen()),
      );

  void _toLogin() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

  Future<void> _register(AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      setState(() => _errorMessage = l.consentError);
      return;
    }
    if (_passwordStrength < 2) {
      setState(() => _errorMessage = l.weakPwError);
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authServiceProvider).registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        companyName: _companyNameController.text.trim(),
      );
      AnalyticsService.logEvent('sign_up', parameters: {'method': 'email'});
      _registered = true;
      FormDraftService.clear(_draftKey);
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
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final credential = await ref.read(authServiceProvider).signInWithGoogle();
      if (credential == null) return; // user closed popup
      AnalyticsService.logEvent('sign_up', parameters: {'method': 'google'});
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
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final credential = await ref.read(authServiceProvider).signInWithApple();
      if (credential == null) return; // user closed popup
      AnalyticsService.logEvent('sign_up', parameters: {'method': 'apple'});
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
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
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
          _register(l);
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
                          Text(l.registerTitle, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5)),
                          const SizedBox(height: 6),
                          Text(l.registerSubtitle, style: TextStyle(fontSize: 16, color: c.textSecondary)),
                          const SizedBox(height: 4),
                          Text(l.registerQuickNote, style: TextStyle(fontSize: 13, color: c.textTertiary)),
                          SizedBox(height: isWide ? 32 : 18),

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

                          Row(
                            children: [
                              Expanded(child: CustomTextField(
                                label: l.firstNameLabel, hint: l.firstNameHint,
                                controller: _firstNameController,
                                validator: (v) => v == null || v.isEmpty ? l.required : null,
                              )),
                              const SizedBox(width: 16),
                              Expanded(child: CustomTextField(
                                label: l.lastNameLabel, hint: l.lastNameHint,
                                controller: _lastNameController,
                                validator: (v) => v == null || v.isEmpty ? l.required : null,
                              )),
                            ],
                          ),
                          SizedBox(height: isWide ? 20 : 14),

                          CustomTextField(
                            label: l.emailLabel, hint: l.emailHint,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => Validators.email(v, l),
                          ),
                          SizedBox(height: isWide ? 20 : 14),

                          CustomTextField(
                            label: l.passwordLabel, hint: l.passwordHint,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: c.textSecondary),
                              tooltip: _obscurePassword ? l.showPasswordTooltip : l.hidePasswordTooltip,
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return l.enterPassword;
                              if (v.length < 8) return l.min8Chars;
                              return null;
                            },
                          ),

                          if (_passwordController.text.isNotEmpty) ...[
                            SizedBox(height: isWide ? 10 : 8),
                            Row(
                              children: [
                                Expanded(child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(value: _passwordStrength / 3, backgroundColor: c.border, color: _strengthColor, minHeight: 6),
                                )),
                                const SizedBox(width: 10),
                                Text(_strengthLabel(l), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _strengthColor)),
                              ],
                            ),
                            SizedBox(height: isWide ? 8 : 6),
                            _PasswordReq(met: _passwordController.text.length >= 8, label: l.req8Chars),
                            _PasswordReq(met: _passwordController.text.contains(RegExp(r'[A-Z]')), label: l.req1Upper),
                            _PasswordReq(met: _passwordController.text.contains(RegExp(r'[0-9]')), label: l.req1Number),
                          ],

                          SizedBox(height: isWide ? 20 : 14),

                          CustomTextField(
                            label: l.companyNameLabel, hint: l.companyNameHint,
                            controller: _companyNameController,
                            validator: (v) => v == null || v.isEmpty ? l.required : null,
                          ),
                          SizedBox(height: isWide ? 20 : 16),

                          // ── Consent ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24, height: 24,
                                child: Checkbox(
                                  value: _consentChecked,
                                  onChanged: (v) => setState(() => _consentChecked = v ?? false),
                                  activeColor: AppColors.primary,
                                  checkColor: Colors.white,
                                  side: BorderSide(color: c.textSecondary, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Wrap(
                                    children: [
                                      Text(l.consentPrefix, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5)),
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AGBScreen())),
                                        child: const Text('AGB', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700, height: 1.5, decoration: TextDecoration.underline, decorationColor: AppColors.primary)),
                                      ),
                                      Text(l.consentMiddle, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5)),
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DatenschutzScreen())),
                                        child: const Text('Datenschutzerklärung', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700, height: 1.5, decoration: TextDecoration.underline, decorationColor: AppColors.primary)),
                                      ),
                                      Text(l.consentSuffix, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isWide ? 16 : 8),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _register(l),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                elevation: 6,
                                shadowColor: AppColors.primary.withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                  : Text(l.registerButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ),
                          ),
                          SizedBox(height: isWide ? 24 : 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l.alreadyRegistered, style: TextStyle(color: c.textSecondary, fontSize: 15)),
                              TextButton(onPressed: _toLogin, child: Text(l.toLogin)),
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

                          _SocialButton(
                            icon: const FaIcon(FontAwesomeIcons.google, size: 17, color: Color(0xFF4285F4)),
                            label: l.continueWithGoogle,
                            onTap: _isLoading ? null : _signUpWithGoogle,
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
                              onTap: _isLoading ? null : _signUpWithApple,
                            ),
                          ],
                          SizedBox(height: isWide ? 24 : 14),

                          // ── Disclaimer ──
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.border)),
                            child: Text(l.registerDisclaimer, style: TextStyle(fontSize: 11, color: c.textTertiary, height: 1.5, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                          ),
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

class _PasswordReq extends StatelessWidget {
  final bool met;
  final String label;
  const _PasswordReq({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 14, color: met ? AppColors.live : c.textTertiary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: met ? AppColors.live : c.textTertiary)),
        ],
      ),
    );
  }
}

// ─── Social Button ────────────────────────────────────────────────────────────
// Mirrors login_screen.dart's _SocialButton exactly, so both auth screens
// share identical hover/disabled treatment for the Google/Apple buttons.

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
