import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/admin_onboarding_provider.dart';
import '../../../core/services/admin_onboarding_service.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../opportunities/screens/create_capacity_screen.dart';

/// Admin-only wizard for the optional phone-onboarding path (Path B). Creates
/// a Firebase account + company profile (+ optional first post) on behalf of a
/// company, then sends them a set-password invite. The self-service flows
/// (register / login / forgot-password) are untouched and remain the default.
class AdminOnboardingScreen extends ConsumerStatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  ConsumerState<AdminOnboardingScreen> createState() =>
      _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState
    extends ConsumerState<AdminOnboardingScreen> {
  int _step = 1;
  bool _busy = false;
  String? _error;

  // Step 1
  final _step1FormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Hamburg');

  // Step 2
  final _descCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();
  String _employees = '1-5';
  final List<String> _selectedTrades = [];

  // Carried across steps once the account exists.
  String? _uid;
  String? _throwawayPassword;
  CompanyModel? _company;
  bool _firstPostDone = false;
  bool _inviteSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    _websiteCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _postalCtrl.dispose();
    _vatCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: create the account ──
  Future<void> _createAccount() async {
    final l = AppLocalizations.of(context);
    if (!_step1FormKey.currentState!.validate()) return;
    final adminUid = ref.read(authStateProvider).valueOrNull?.uid ?? '';

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = CompanyModel(
        id: '',
        ownerId: '',
        name: _nameCtrl.text.trim(),
        description: '',
        website: '',
        email: _emailCtrl.text.trim(),
        phone: '',
        address: '',
        city: _cityCtrl.text.trim().isEmpty ? 'Hamburg' : _cityCtrl.text.trim(),
        postalCode: '',
        country: 'Deutschland',
        employees: '1-5',
        trades: const [],
        services: const [],
        logoUrl: '',
        // verificationStatus 'none' + contentFlagged false (model defaults)
        // satisfy the companies create rule, exactly like self-registration.
      );

      final account = await ref
          .read(adminOnboardingServiceProvider)
          .createCompanyAccount(
            email: _emailCtrl.text.trim(),
            companyDraft: draft,
            adminUid: adminUid,
          );

      setState(() {
        _uid = account.uid;
        _throwawayPassword = account.password;
        _company = draft.copyWith(
          id: account.uid,
          ownerId: account.uid,
          onboardingSource: 'admin',
          onboardingAdminUid: adminUid,
        );
        _step = 2;
      });
    } on OnboardingException catch (e) {
      setState(() => _error =
          e.code == 'email-already-in-use' ? l.onboardEmailInUseError : l.onboardGenericError);
    } catch (_) {
      setState(() => _error = l.onboardGenericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 2: save full profile (optional) ──
  Future<void> _saveProfile() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final vat = _vatCtrl.text.trim();
      final updated = _company!.copyWith(
        description: _descCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim(),
        vatNumber: vat,
        employees: _employees,
        trades: List<String>.from(_selectedTrades),
        // Mirror self-service: requesting a VAT moves to 'pending' review;
        // otherwise stays 'none'. Admins verify separately.
        verificationStatus: vat.isNotEmpty ? 'pending' : 'none',
      );
      await ref
          .read(adminOnboardingServiceProvider)
          .updateCompanyProfile(_uid!, updated);
      setState(() {
        _company = updated;
        _step = 3;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.onboardProfileSavedSnackbar), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      setState(() => _error = l.errorWithMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 3: optional first post ──
  Future<void> _openFirstPost() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCapacityScreen(
          company: _company!,
          onSubmitOverride: (capacity, owner) => ref
              .read(adminOnboardingServiceProvider)
              .createFirstCapacityPost(
                email: _company!.email,
                throwawayPassword: _throwawayPassword!,
                capacityDraft: capacity,
                ownerDraft: owner,
              ),
        ),
      ),
    );
    // CreateCapacityScreen pops itself after a successful post. We can't tell a
    // successful post from a cancel with certainty, so we surface a soft "done"
    // marker and leave the admin in control of advancing.
    if (mounted) setState(() => _firstPostDone = true);
  }

  // ── Step 4: send the invite ──
  Future<void> _sendInvite() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(
            _company!.email,
            languageCode: 'de',
            continueUrl: 'https://capacify-mvp.web.app/',
          );
      await ref.read(adminOnboardingServiceProvider).markInvited(_uid!);
      setState(() => _inviteSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.onboardInviteSentSnackbar), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      setState(() => _error = l.errorWithMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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
        title: Text(l.onboardTabTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepHeader(current: _step),
                const SizedBox(height: 20),
                if (_step == 1) _buildStep1(l),
                if (_step == 2) _buildStep2(l),
                if (_step == 3) _buildStep3(l),
                if (_step == 4) _buildStep4(l),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }

  Widget _stepTitle(String title, String subtitle) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
      ],
    );
  }

  Widget _buildStep1(AppLocalizations l) {
    return _card(
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stepTitle(l.onboardStep1Title, l.onboardStep1Subtitle),
            const SizedBox(height: 20),
            CustomTextField(
              label: l.onboardEmailLabel,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => Validators.email(v, l),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: l.onboardCompanyNameLabel,
              controller: _nameCtrl,
              validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(label: l.cityLabel, controller: _cityCtrl),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _createAccount,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.onboardCreateAccountButton, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(AppLocalizations l) {
    final c = AppColors.of(context);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AccountCreatedBanner(email: _company!.email),
          const SizedBox(height: 16),
          _stepTitle(l.onboardStep2Title, l.onboardStep2Subtitle),
          const SizedBox(height: 18),
          CustomTextField(label: l.descriptionRequiredLabel, controller: _descCtrl),
          const SizedBox(height: 14),
          // Trades (max 2), same chip pattern as the company profile screen.
          Text(l.tradeBranchLabel, style: TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kTrades.map((trade) {
              final isSelected = _selectedTrades.contains(trade);
              final atLimit = _selectedTrades.length >= 2 && !isSelected;
              return FilterChip(
                label: Text(l.tradeName(trade)),
                selected: isSelected,
                onSelected: atLimit
                    ? null
                    : (sel) => setState(() {
                          if (sel) {
                            _selectedTrades.add(trade);
                          } else {
                            _selectedTrades.remove(trade);
                          }
                        }),
                backgroundColor: c.surfaceVariant,
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : (atLimit ? c.textTertiary : c.textSecondary),
                  fontSize: 13,
                ),
                side: BorderSide(color: isSelected ? AppColors.primary : c.border),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          CustomTextField(label: l.phoneLabel, controller: _phoneCtrl, keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          CustomTextField(label: l.websiteLabel, controller: _websiteCtrl, keyboardType: TextInputType.url),
          const SizedBox(height: 14),
          CustomTextField(label: l.addressLabel, controller: _addressCtrl),
          const SizedBox(height: 14),
          CustomTextField(
            label: l.postalCodeLabel,
            controller: _postalCtrl,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          CustomTextField(label: l.vatLabel, controller: _vatCtrl),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(l.onboardSaveProfileButton, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _step = 3),
                child: Text(l.skipButton),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(AppLocalizations l) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(l.onboardStep3Title, l.onboardStep3Subtitle),
          if (_firstPostDone) ...[
            const SizedBox(height: 16),
            _DoneBanner(text: l.onboardFirstPostDoneBanner),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _busy ? null : _openFirstPost,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.onboardAddFirstPostButton),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : () => setState(() => _step = 4),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(
              _firstPostDone ? l.onboardFinishButton : l.onboardSkipPostButton,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4(AppLocalizations l) {
    final c = AppColors.of(context);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(l.onboardStep4Title, l.onboardStep4Subtitle),
          const SizedBox(height: 16),
          if (_inviteSent) ...[
            _DoneBanner(text: l.onboardInviteSentSnackbar),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(l.onboardFinishButton, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ] else ...[
            Text(
              l.onboardInviteSummary(_company!.name, _company!.email),
              style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _busy ? null : _sendInvite,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.onboardSendInviteButton, style: const TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int current;
  const _StepHeader({required this.current});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: List.generate(4, (i) {
        final step = i + 1;
        final done = step < current;
        final active = step == current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            height: 5,
            decoration: BoxDecoration(
              color: (done || active) ? AppColors.primary : c.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _AccountCreatedBanner extends StatelessWidget {
  final String email;
  const _AccountCreatedBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DoneBanner(text: '${l.onboardAccountCreatedBanner}  ·  $email');
  }
}

class _DoneBanner extends StatelessWidget {
  final String text;
  const _DoneBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
