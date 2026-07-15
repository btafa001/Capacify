import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_provider.dart';

/// Persistent banner while the signed-in user's email is unverified — posting
/// a capacity and contacting a company are both gated on it (firestore.rules:
/// email_verified must be true on the caller's ID token), so this is the
/// visible half of that gate, not just decoration. OAuth accounts (Google/
/// Apple) start verified automatically and never see this. Absent entirely
/// once emailVerified is true.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends ConsumerState<EmailVerificationBanner> {
  bool _busy = false;
  String? _feedback;

  Future<void> _resend() async {
    final l = AppLocalizations.of(context);
    setState(() { _busy = true; _feedback = null; });
    try {
      await ref.read(authServiceProvider).resendVerificationEmail();
      if (mounted) setState(() => _feedback = l.verificationEmailResent);
    } catch (e) {
      if (mounted) setState(() => _feedback = l.errorWithMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() { _busy = true; _feedback = null; });
    final verified = await ref.read(authServiceProvider).reloadAndCheckEmailVerified();
    if (!mounted) return;
    setState(() {
      _busy = false;
      // A no-op if still unverified — the banner just stays; ref.watch on the
      // auth stream elsewhere doesn't re-emit from a plain token refresh, so
      // rebuilding this widget's own state is what makes the banner disappear
      // the moment it actually is verified.
      if (verified) ref.invalidate(authStateProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null || user.emailVerified) return const SizedBox.shrink();

    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 720;

    final text = Text(
      _feedback ?? l.verifyEmailBannerBody,
      style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
    );

    final buttons = [
      TextButton(
        onPressed: _busy ? null : _resend,
        child: Text(l.resendVerificationButton,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.warning)),
      ),
      const SizedBox(width: 4),
      OutlinedButton(
        onPressed: _busy ? null : _refresh,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: _busy
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l.iveVerifiedButton, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    ];

    return Material(
      color: AppColors.warning.withOpacity(0.10),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.warning.withOpacity(0.35)))),
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: SafeArea(
          bottom: false,
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.mark_email_unread_outlined, size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(child: text),
                    ]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: buttons),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.mark_email_unread_outlined, size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    ...buttons,
                  ],
                ),
        ),
      ),
    );
  }
}
