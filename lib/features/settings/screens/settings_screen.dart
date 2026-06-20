import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/seed_service.dart';
import '../../landing/screens/landing_screen.dart';
import '../../legal/screens/agb_screen.dart';
import '../../legal/screens/datenschutz_screen.dart';
import '../../legal/screens/impressum_screen.dart';
import '../../../core/localization/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends ConsumerState<SettingsScreen> {
  bool _emailNotifications = true;
  bool _newPostAlerts = true;
  bool _messageAlerts = false;

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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ── NOTIFICATIONS ──
                  _SectionLabel(
                      label: l.notificationsSection),
                  const SizedBox(height: 10),

                  _SettingsCard(
                    children: [
                      _ToggleTile(
                        icon: Icons.email_outlined,
                        title: l.emailNotificationsTitle,
                        subtitle: l.emailNotificationsSubtitle,
                        value: _emailNotifications,
                        onChanged: (v) => setState(
                          () => _emailNotifications = v,
                        ),
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.flash_on_outlined,
                        title: l.newCapacitiesTitle,
                        subtitle: l.newPostingsSubtitle,
                        value: _newPostAlerts,
                        onChanged: (v) => setState(
                          () => _newPostAlerts = v,
                        ),
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.chat_outlined,
                        title: l.messagesTitle,
                        subtitle: l.newMessagesSubtitle,
                        value: _messageAlerts,
                        onChanged: (v) => setState(
                          () => _messageAlerts = v,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── LEGAL ──
                  _SectionLabel(label: l.legalSection),
                  const SizedBox(height: 10),

                  _SettingsCard(
                    children: [
                      _LinkTile(
                        icon: Icons.description_outlined,
                        title: l.agbLabel,
                        subtitle: l.agbFullName,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AGBScreen(),
                          ),
                        ),
                      ),
                      _Divider(),
                      _LinkTile(
                        icon: Icons.security_outlined,
                        title: l.privacyLabel,
                        subtitle: l.gdprSubtitle,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const DatenschutzScreen(),
                          ),
                        ),
                      ),
                      _Divider(),
                      _LinkTile(
                        icon: Icons.info_outline,
                        title: l.footerImprint,
                        subtitle: l.tmgSubtitle,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ImpressumScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── ABOUT ──
                  _SectionLabel(label: l.aboutCapacifySection),
                  const SizedBox(height: 10),

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
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                              ),
                              child: const Center(
                                child: Text(
                                  'C',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
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
                        const SizedBox(height: 14),
                        Divider(color: c.border),
                        const SizedBox(height: 10),
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

                  const SizedBox(height: 28),

                  // ── DEMO DATA ──
                  _SectionLabel(label: l.developerSection),
                  const SizedBox(height: 10),
                  const _DemoDataSection(),

                  const SizedBox(height: 28),

                  // ── ACCOUNT ──
                  _SectionLabel(label: l.accountSectionCaps),
                  const SizedBox(height: 10),

                  _SettingsCard(
                    children: [
                      _LinkTile(
                        icon: Icons.lock_outline,
                        title: l.changePasswordTitle,
                        subtitle: l.setNewPasswordSubtitle,
                        onTap: _showChangePasswordDialog,
                      ),
                      _Divider(),
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

                  const SizedBox(height: 36),

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

                  const SizedBox(height: 20),
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