import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/seed_service.dart';
import '../../../core/services/admin_provider.dart';
import '../../../shared/widgets/capacify_logo.dart';
import '../../landing/screens/landing_screen.dart';
import '../../landing/screens/about_screen.dart';
import '../../legal/screens/agb_screen.dart';
import '../../legal/screens/datenschutz_screen.dart';
import '../../legal/screens/impressum_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/consent_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/privacy_service.dart';
import '../../../shared/widgets/invite_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends ConsumerState<SettingsScreen> {
  bool _emailNotifications = true;
  bool _newPostAlerts = false;
  bool _messageAlerts = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('Settings');
    _loadEmailNotificationPref();
  }

  Future<void> _loadEmailNotificationPref() async {
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final on = await auth.getEmailNotifications(uid);
    final messageAlertsOn = await auth.getNotifyOnNewMessage(uid);
    // Retention-email opt-in lives on the company doc (what the Cloud Functions
    // read); load it into the "new matching capacities" toggle.
    final company = await ref.read(companyServiceProvider).getCompanyByOwner(uid);
    if (mounted) {
      setState(() {
        _emailNotifications = on;
        _newPostAlerts = company?.emailOptIn ?? false;
        _messageAlerts = messageAlertsOn;
      });
    }
  }

  Future<void> _setEmailNotifications(bool v) async {
    setState(() => _emailNotifications = v);
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      await auth.setEmailNotifications(uid: uid, enabled: v);
    }
  }

  /// Gates the onNewMessage Cloud Function's push + email (see functions/index.js).
  Future<void> _setMessageAlerts(bool v) async {
    setState(() => _messageAlerts = v);
    final auth = ref.read(authServiceProvider);
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      await auth.setNotifyOnNewMessage(uid: uid, enabled: v);
    }
  }

  /// Opt in/out of the retention emails (match alerts + weekly digest). Writes
  /// the company's emailOptIn flag that notifyOnNewCapacity / weeklyDigest read.
  Future<void> _setNewCapacityAlerts(bool v) async {
    setState(() => _newPostAlerts = v);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      await ref.read(companyServiceProvider).setEmailOptIn(uid, v);
    }
  }

  Future<void> _exportData() async {
    final l = AppLocalizations.of(context);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(privacyServiceProvider).downloadMyData(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.exportDataStarted), backgroundColor: AppColors.live));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.genericErrorRetry), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final l = AppLocalizations.of(context);
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(l.deleteAccountConfirmTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
        content: Text(l.deleteAccountConfirmBody,
            style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteAccountConfirmCta,
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(privacyServiceProvider).deleteMyAccount(uid);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Firebase requires a recent login to delete the Auth user; surface a
      // clear "please sign in again, then retry" rather than a raw exception.
      final msg = e.toString().contains('requires-recent-login')
          ? l.deleteAccountReauthNeeded
          : l.genericErrorRetry;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    }
  }

  void _showChangePasswordDialog() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => ChangePasswordDialog(
        authService: ref.read(authServiceProvider),
      ),
    );
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).passwordChangedSuccess),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    final referralCount = uid == null ? 0 : ref.watch(referralCountProvider(uid)).valueOrNull ?? 0;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: c.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.settingsTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ── NOTIFICATIONS ──
                  _SectionLabel(label: l.notificationsSection),
                  SizedBox(height: isMobile ? 8 : 10),

                  _SettingsCard(
                    children: [
                      // Live, persisted preference: email me on new requests.
                      _ToggleTile(
                        icon: Icons.email_outlined,
                        title: l.emailNotificationsTitle,
                        subtitle: l.emailNotificationsSubtitle,
                        value: _emailNotifications,
                        onChanged: _setEmailNotifications,
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.flash_on_outlined,
                        title: l.newCapacitiesTitle,
                        subtitle: l.newPostingsSubtitle,
                        value: _newPostAlerts,
                        onChanged: _setNewCapacityAlerts,
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.chat_outlined,
                        title: l.messagesTitle,
                        subtitle: l.newMessagesSubtitle,
                        value: _messageAlerts,
                        onChanged: _setMessageAlerts,
                      ),
                    ],
                  ),

                  SizedBox(height: isMobile ? 16 : 28),

                  // ── ACCOUNT ──
                  _SectionLabel(label: l.accountSectionCaps),
                  SizedBox(height: isMobile ? 8 : 10),

                  _SettingsCard(
                    children: [
                      _LinkTile(
                        icon: Icons.lock_outline,
                        title: l.changePasswordTitle,
                        subtitle: l.setNewPasswordSubtitle,
                        onTap: _showChangePasswordDialog,
                      ),
                      _Divider(),
                      // Referral attribution (see AuthService._referrerFromUrl,
                      // CompanyModel.referredBy) — recognition for bringing
                      // companies in, not a credit/quota bonus: during Early
                      // Access every company already has an effectively
                      // unlimited monthly quota, so crediting more of the
                      // same wouldn't actually motivate anything. Revisit once
                      // real pricing exists and a bonus would mean something.
                      _LinkTile(
                        icon: Icons.person_add_alt_1_outlined,
                        title: l.referralsTitle,
                        subtitle: referralCount > 0
                            ? l.referralsCountSubtitle(referralCount)
                            : l.referralsNoneYetSubtitle,
                        onTap: () => showInviteDialog(context, companyId: uid),
                      ),
                      _Divider(),
                      // Pricing entry intentionally hidden for the free-contact
                      // launch (no credits/payment). PricingScreen + credit infra
                      // stay in the codebase, dormant, for a future paid revival.
                      _LinkTile(
                        icon: Icons.logout,
                        title: l.signOut,
                        subtitle: l.signOutSubtitle,
                        iconColor: AppColors.error,
                        titleColor: AppColors.error,
                        onTap: () async {
                          await ref.read(authServiceProvider).signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LandingScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: isMobile ? 16 : 28),

                  // ── ABOUT ──
                  _SectionLabel(label: l.aboutCapacifySection),
                  SizedBox(height: isMobile ? 8 : 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                          color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          ),
                          child: Row(
                            children: [
                              const CapacifySymbol(size: 40),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    'Capacify',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w900,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    l.liveCapacityExchangeTagline,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 10 : 14),
                        Divider(color: c.border),
                        SizedBox(height: isMobile ? 8 : 10),
                        Text(
                          'Version 1.0.0 (MVP)',
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '© 2026 Capacify.',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── DEMO DATA (admins only) ──
                  if (ref.watch(isAdminProvider).valueOrNull == true) ...[
                    SizedBox(height: isMobile ? 16 : 28),
                    _SectionLabel(label: l.developerSection),
                    SizedBox(height: isMobile ? 8 : 10),
                    const _DemoDataSection(),
                  ],

                  SizedBox(height: isMobile ? 16 : 28),

                  // ── DATENSCHUTZ & RECHTLICHES (privacy controls + legal docs) ──
                  _SectionLabel(label: l.privacyLegalSectionCaps),
                  SizedBox(height: isMobile ? 8 : 10),

                  _SettingsCard(
                    children: [
                      // Analytics consent as a real switch (clearer than a tap-to-toggle row).
                      _ToggleTile(
                        icon: Icons.analytics_outlined,
                        title: l.consentSettingsTitle,
                        subtitle: l.consentSettingsSubtitle,
                        value: ref.watch(consentProvider) == ConsentState.granted,
                        onChanged: (v) {
                          final n = ref.read(consentProvider.notifier);
                          v ? n.grant() : n.deny();
                        },
                      ),
                      _Divider(),
                      _LinkTile(
                        icon: Icons.security_outlined,
                        title: l.privacyLabel,
                        subtitle: l.gdprSubtitle,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const DatenschutzScreen())),
                      ),
                      _Divider(),
                      _LinkTile(
                        icon: Icons.description_outlined,
                        title: l.agbLabel,
                        subtitle: l.agbFullName,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AGBScreen())),
                      ),
                      _Divider(),
                      _LinkTile(
                        icon: Icons.info_outline,
                        title: l.footerImprint,
                        subtitle: l.tmgSubtitle,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ImpressumScreen())),
                      ),
                      _Divider(),
                      _LinkTile(
                        icon: Icons.download_outlined,
                        title: l.exportDataTitle,
                        subtitle: l.exportDataSubtitle,
                        onTap: _exportData,
                      ),
                    ],
                  ),

                  SizedBox(height: isMobile ? 20 : 32),

                  // Disclaimer
                  Center(
                    child: Text(
                      l.footerDisclaimer,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textTertiary,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 10 : 14),

                  // Danger action — deliberately de-emphasised (small, muted text
                  // link at the very bottom) so account deletion isn't a prominent
                  // button that gets hit by accident. The confirm dialog guards it.
                  Center(
                    child: TextButton.icon(
                      onPressed: _confirmDeleteAccount,
                      icon: Icon(Icons.delete_outline, size: 15, color: c.textTertiary),
                      label: Text(
                        l.deleteAccountTitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textTertiary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 12 : 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets private to this file ──

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Divider(
      height: 1,
      color: c.border,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: c.textSecondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? c.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? c.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: iconColor ?? c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Change Password Dialog ────────────────────────────

class ChangePasswordDialog extends StatefulWidget {
  final AuthService authService;
  const ChangePasswordDialog({super.key, required this.authService});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await widget.authService.changePassword(
        currentPassword: _currentPwCtrl.text,
        newPassword: _newPwCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Widget _pwField({
    required String label,
    required TextEditingController ctrl,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    final c = AppColors.of(context);
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: c.textSecondary,
            size: 18,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        l.changePasswordTitle,
        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _pwField(
                label: l.currentPasswordLabel,
                ctrl: _currentPwCtrl,
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (v) => v == null || v.isEmpty ? l.required : null,
              ),
              const SizedBox(height: 14),
              _pwField(
                label: l.newPasswordLabel,
                ctrl: _newPwCtrl,
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.required;
                  if (v.length < 6) return l.min6CharsError;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _pwField(
                label: l.confirmNewPasswordLabel,
                ctrl: _confirmPwCtrl,
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.required;
                  if (v != _newPwCtrl.text) return l.passwordsDontMatchError;
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: Text(l.cancel, style: TextStyle(color: c.textSecondary)),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(l.saveButtonGeneric, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Demo Data Section ─────────────────────────────────

class _DemoDataSection extends StatefulWidget {
  const _DemoDataSection();

  @override
  State<_DemoDataSection> createState() => _DemoDataSectionState();
}

class _DemoDataSectionState extends State<_DemoDataSection> {
  final _seedService = SeedService();
  bool _loading = false;
  bool? _isSeeded;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final seeded = await _seedService.isDemoSeeded();
    if (mounted) setState(() => _isSeeded = seeded);
  }

  Future<void> _doSeed() async {
    final l = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await _seedService.seedAll();
      if (mounted) {
        setState(() {
          _loading = false;
          _isSeeded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.demoDataSeededSuccess),
            backgroundColor: const Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorWithMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _doSeedRatings() async {
    final l = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      await _seedService.seedRatings();
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.demoRatingsSeededSuccess),
            backgroundColor: const Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorWithMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _doClear() async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text(
          l.clearDemoDataTitle,
          style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w900),
        ),
        content: Text(
          l.clearDemoDataBody,
          style: TextStyle(
              color: c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel,
                style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.deleteButton,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await _seedService.clearDemoData();
      if (mounted) {
        setState(() {
          _loading = false;
          _isSeeded = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.demoDataClearedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorWithMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dataset_outlined,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.sampleDataTitle,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: c.textPrimary),
                    ),
                    Text(
                      l.sampleDataSubtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_isSeeded == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l.statusActiveBadge,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2ECC71)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 14),
          if (_loading || _isSeeded == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!_isSeeded!)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _doSeed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(
                  l.seedSampleDataButton,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _doSeedRatings,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(
                          color: AppColors.accent.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: Text(
                      l.seedDemoRatingsButton,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _doClear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(
                      l.clearSampleDataButton,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}