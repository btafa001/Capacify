import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/capacity_owner_model.dart';
import '../../../core/models/contact_request_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/contact_request_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/content_moderation.dart';
import '../../messaging/screens/chat_screen.dart';

/// The FREE, message-first connection flow (launch phase — no credits, no
/// payment). You write a real first message; it's sent anonymously to the
/// poster, who is notified and can Accept → both identities reveal and a chat
/// opens. Re-opening a post you've already messaged shows the current state
/// (awaiting reply / connected). Kept the name `showInterestModal` so existing
/// call sites don't change.
Future<void> showInterestModal({
  required BuildContext context,
  required WidgetRef ref,
  required CapacityModel capacity,
}) async {
  final l = AppLocalizations.of(context);
  void snack(String m, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: color));

  final user = ref.read(authStateProvider).value;
  if (user == null) {
    snack(l.completeProfileToRequestNotice, AppColors.error);
    return;
  }
  final requester = await ref.read(myCompanyProvider(user.uid).future);
  if (requester == null || !requester.isProfileComplete) {
    snack(l.completeProfileToRequestNotice, AppColors.error);
    return;
  }
  if (!context.mounted) return;

  // Sidecar readable ⇒ I'm the owner, an admin, or already connected (granted).
  final owner =
      await ref.read(capacityServiceProvider).getCapacityOwner(capacity.id);
  // My existing request for this post (drives "already sent" vs "connected").
  final existing = await ref
      .read(contactRequestServiceProvider)
      .myRequestForPost(requesterCompanyId: requester.id, postId: capacity.id)
      .first;
  if (!context.mounted) return;

  final c = AppColors.of(context);
  final accent = capacity.type == CapacityType.offer
      ? AppColors.offerColor
      : AppColors.needColor;
  final requestId = ContactRequestModel.idFor(requester.id, capacity.id);
  final messageController = TextEditingController();
  final size = MediaQuery.of(context).size;

  final bool isOwnPost = owner != null && owner.posterCompanyId == requester.id;
  final bool isConnected = !isOwnPost && (existing?.status == 'granted');

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: l.cancel,
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1.0)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: FadeTransition(opacity: anim, child: child),
    ),
    pageBuilder: (ctx, _, __) {
      String? sentStatus = existing?.status; // null | pending | declined | granted
      bool sending = false;

      void openChat() {
        Navigator.pop(ctx);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: requestId,
              myCompanyId: requester.id,
              otherCompanyId: owner!.posterCompanyId,
              otherCompanyName: owner.companyName,
              postId: capacity.id,
            ),
          ),
        );
      }

      return Align(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: size.width < 600 ? 16 : 40, vertical: 24),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: 460, maxHeight: size.height * 0.9),
            child: Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              child: StatefulBuilder(
                builder: (ctx, setState) {
                  Future<void> send() async {
                    if (sending) return;
                    setState(() => sending = true);
                    try {
                      await ref
                          .read(contactRequestServiceProvider)
                          .requestContact(
                            post: capacity,
                            requester: requester,
                            message: messageController.text,
                          );
                      ref
                          .read(capacityServiceProvider)
                          .incrementInterestCount(capacity.id);
                      AnalyticsService.logEvent('message_sent_to_poster',
                          parameters: {'trade': capacity.trade});
                      setState(() {
                        sentStatus = 'pending';
                        sending = false;
                      });
                      snack(l.messageSentSnackbar, AppColors.live);
                    } catch (e) {
                      setState(() => sending = false);
                      snack(l.errorWithMessage(e), AppColors.error);
                    }
                  }

                  Widget body;
                  if (isOwnPost) {
                    body = const _OwnPostBody();
                  } else if (isConnected) {
                    body = _ConnectedBody(
                        owner: owner!, accent: accent, onChat: openChat);
                  } else if (sentStatus == 'declined') {
                    body = const _StatusBody(
                        icon: Icons.do_not_disturb_on_outlined,
                        color: AppColors.error,
                        titleKey: 'declined');
                  } else if (sentStatus == 'pending') {
                    body = const _StatusBody(
                        icon: Icons.mark_email_read_outlined,
                        color: AppColors.live,
                        titleKey: 'sent');
                  } else {
                    body = _ComposeBody(
                      capacity: capacity,
                      accent: accent,
                      sending: sending,
                      messageController: messageController,
                      onChanged: () => setState(() {}),
                      onSend: send,
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(Icons.close,
                                  size: 20, color: c.textTertiary),
                            ),
                          ),
                        ),
                        body,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
  messageController.dispose();
}

class _ComposeBody extends StatelessWidget {
  final CapacityModel capacity;
  final Color accent;
  final bool sending;
  final TextEditingController messageController;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  const _ComposeBody({
    required this.capacity,
    required this.accent,
    required this.sending,
    required this.messageController,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final flagged = containsContactInfo(messageController.text);
    final canSend = messageController.text.trim().isNotEmpty && !sending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.forum_outlined, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.sendMessageButton,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(l.messageComposerSubtitle,
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.45)),
        const SizedBox(height: 16),
        // Anonymized summary of what you're replying to.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withOpacity(0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.interestSummaryLabel.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: accent)),
            const SizedBox(height: 6),
            Text('${capacity.workerCount} ${l.tradeName(capacity.trade)}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary)),
            const SizedBox(height: 2),
            Text('${capacity.location} · ${capacity.availabilityLabel(l)}',
                style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: messageController,
          maxLines: 3,
          maxLength: 400,
          autofocus: true,
          onChanged: (_) => onChanged(),
          style: TextStyle(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: l.interestMessageHint,
            hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
            filled: true,
            fillColor: c.background,
            counterStyle: TextStyle(color: c.textTertiary, fontSize: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (flagged)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.interestContainsContactWarning,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.warning, height: 1.35)),
              ),
            ]),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canSend ? onSend : null,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(l.sendMessageButton,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectedBody extends StatelessWidget {
  final CapacityOwnerModel owner;
  final Color accent;
  final VoidCallback onChat;
  const _ConnectedBody(
      {required this.owner, required this.accent, required this.onChat});

  Future<void> _launch(String scheme, String value) async {
    if (value.isEmpty) return;
    try {
      await launchUrl(Uri.parse('$scheme$value'));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.live.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline,
              color: AppColors.live, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(l.vermittlungUnlockedTitle,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: c.textPrimary)),
        ),
      ]),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.live.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.live.withOpacity(0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(owner.companyName,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: c.textPrimary)),
          if (owner.contactPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _launch('tel:', owner.contactPhone),
              child: Row(children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.live),
                const SizedBox(width: 8),
                Text(owner.contactPhone,
                    style: const TextStyle(
                        color: AppColors.live,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          if (owner.contactEmail.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _launch('mailto:', owner.contactEmail),
              child: Row(children: [
                const Icon(Icons.mail_outline, size: 16, color: AppColors.live),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(owner.contactEmail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.live,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onChat,
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: Text(l.sendMessageButton,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]);
  }
}

class _OwnPostBody extends StatelessWidget {
  const _OwnPostBody();
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.person_outline, color: c.textSecondary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(l.ownPostTitle,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: c.textPrimary)),
        ),
      ]),
      const SizedBox(height: 12),
      Text(l.ownPostBody,
          style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.5)),
      const SizedBox(height: 8),
    ]);
  }
}

/// Sent-awaiting-reply or declined confirmation.
class _StatusBody extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titleKey; // 'sent' | 'declined'
  const _StatusBody(
      {required this.icon, required this.color, required this.titleKey});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final title = titleKey == 'declined' ? l.messageDeclinedTitle : l.messageSentTitle;
    final bodyText = titleKey == 'declined' ? l.messageDeclinedBody : l.messageSentBody;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: c.textPrimary)),
        ),
      ]),
      const SizedBox(height: 12),
      Text(bodyText,
          style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.5)),
      const SizedBox(height: 8),
    ]);
  }
}
