import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../core/constants/app_constants.dart';
import '../../legal/screens/agb_screen.dart';
import '../../legal/screens/datenschutz_screen.dart';

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
  final _companyEmailController = TextEditingController();
  final _phoneController        = TextEditingController();
  final _cityController         = TextEditingController();
  final _websiteController      = TextEditingController();
  final _vatNumberController    = TextEditingController();

  String _selectedTrade = kTrades[0];
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _consentChecked = false;
  String? _errorMessage;
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (mounted) _checkPasswordStrength(_passwordController.text);
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _websiteController.dispose();
    _vatNumberController.dispose();
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
        trade: _selectedTrade,
        city: _cityController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim(),
        companyEmail: _companyEmailController.text.trim(),
        vatNumber: _vatNumberController.text.trim(),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
              child: const Center(child: Text('C', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 10),
            Text('Capacify', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary)),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── HEADER ──
                  Text(l.registerTitle, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text(l.registerSubtitle, style: TextStyle(fontSize: 15, color: c.textSecondary)),
                  const SizedBox(height: 36),

                  // ── ERROR ──
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
                    const SizedBox(height: 20),
                  ],

                  // ── SECTION 1: PERSONAL ──
                  _RegisterSectionHeader(label: l.sectionPersonal, icon: Icons.person_outline),
                  const SizedBox(height: 16),

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
                  const SizedBox(height: 20),

                  CustomTextField(
                    label: '${l.emailLabel} *', hint: l.emailHint,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return l.enterEmail;
                      if (!v.contains('@') || !v.contains('.')) return l.invalidEmailAddr;
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    label: '${l.passwordLabel} *', hint: l.passwordHint,
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: c.textSecondary),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l.enterPassword;
                      if (v.length < 8) return l.min8Chars;
                      return null;
                    },
                  ),

                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 8),
                    _PasswordReq(met: _passwordController.text.length >= 8, label: l.req8Chars),
                    _PasswordReq(met: _passwordController.text.contains(RegExp(r'[A-Z]')), label: l.req1Upper),
                    _PasswordReq(met: _passwordController.text.contains(RegExp(r'[0-9]')), label: l.req1Number),
                  ],

                  const SizedBox(height: 32),

                  // ── SECTION 2: COMPANY ──
                  _RegisterSectionHeader(label: l.sectionCompany, icon: Icons.domain_outlined),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: l.companyNameLabel, hint: l.companyNameHint,
                    controller: _companyNameController,
                    validator: (v) => v == null || v.isEmpty ? l.required : null,
                  ),
                  const SizedBox(height: 20),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.tradeLabel, style: TextStyle(color: c.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedTrade,
                        dropdownColor: c.surface,
                        style: TextStyle(color: c.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(),
                        items: kTrades.map((t) => DropdownMenuItem(value: t, child: Text(l.tradeName(t)))).toList(),
                        onChanged: (v) => setState(() => _selectedTrade = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: CustomTextField(
                        label: l.cityLabel, hint: l.cityHint,
                        controller: _cityController,
                        validator: (v) => v == null || v.isEmpty ? l.required : null,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: CustomTextField(
                        label: l.phoneLabel, hint: l.phoneHint,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    label: l.companyEmailLabel, hint: l.companyEmailHint,
                    controller: _companyEmailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return l.required;
                      if (!v.contains('@') || !v.contains('.')) return l.invalidEmailAddr;
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    label: l.websiteLabel, hint: 'https://www.company.com',
                    controller: _websiteController,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 32),

                  // ── SECTION 3: VERIFICATION ──
                  _RegisterSectionHeader(label: l.sectionVerify, icon: Icons.verified_outlined),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: l.vatLabel, hint: l.vatHint,
                    controller: _vatNumberController,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(r'^DE[0-9]{9}$').hasMatch(v)) return l.vatError;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.live.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.live.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.verified, size: 15, color: AppColors.live),
                          const SizedBox(width: 8),
                          Text(l.verifyHowTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.live)),
                        ]),
                        const SizedBox(height: 10),
                        Text(l.verifySteps, style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── CONSENT ──
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
                  const SizedBox(height: 24),

                  // ── REGISTER BUTTON ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_consentChecked) ? null : () => _register(l),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                        minimumSize: const Size(double.infinity, 56),
                        elevation: 6,
                        shadowColor: AppColors.primary.withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(l.registerButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── DISCLAIMER ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.border)),
                    child: Text(l.registerDisclaimer, style: TextStyle(fontSize: 11, color: c.textTertiary, height: 1.5, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.alreadyRegistered, style: TextStyle(color: c.textSecondary, fontSize: 15)),
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(l.toLogin)),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _RegisterSectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
        ]),
        const SizedBox(height: 8),
        Divider(color: c.border),
      ],
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
