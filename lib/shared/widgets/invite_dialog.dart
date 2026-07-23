import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

/// Opens the "invite a company" dialog — the founder's / a member's zero-cost
/// growth lever. Shares a prefilled German/English invitation to the public app
/// URL via clipboard, e-mail (mailto) or WhatsApp. No private data, no backend.
///
/// [companyId], when given, is appended as ?ref={companyId} so a signup via
/// this link is attributable back to the inviter (see AuthService's
/// referrerFromUrl and CompanyModel.referredBy) — shown back to the inviter
/// as an "Empfehlungen: Nx" count in Settings.
Future<void> showInviteDialog(BuildContext context, {String? companyId}) {
  return showDialog(
    context: context,
    builder: (_) => InviteDialog(companyId: companyId),
  );
}

class InviteDialog extends StatelessWidget {
  final String? companyId;
  const InviteDialog({super.key, this.companyId});

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppColors.of(context);
    final message = (companyId == null || companyId!.isEmpty)
        ? l.inviteMessage
        : l.inviteMessage.replaceFirst(
            'https://capacify.de',
            'https://capacify.de/?ref=$companyId',
          );

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.inviteTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textTertiary, size: 20),
                    tooltip: l.closeTooltip,
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l.inviteSubtitle,
                style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),
              // Prefilled message preview.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  message,
                  style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 18),
              // Primary action: copy the invitation.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: message));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.inviteCopied)),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(l.inviteCopyLink),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _launch(Uri.parse(
                      'mailto:?subject=${Uri.encodeComponent(l.inviteEmailSubject)}'
                      '&body=${Uri.encodeComponent(message)}')),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: Text(l.inviteViaEmail),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _launch(Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(message)}')),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: Text(l.inviteViaWhatsapp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
