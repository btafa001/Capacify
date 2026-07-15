import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/chat_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/chat_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/contact_request_provider.dart';
import '../../../core/services/analytics_service.dart';
import 'chat_screen.dart';

/// The "Nachrichten" inbox — every accepted connection the user is chatting in,
/// newest activity first. This is the stickiness home: a reason to come back.
class MessagesInboxScreen extends ConsumerWidget {
  final bool embedded;
  const MessagesInboxScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AnalyticsService.logScreenView('MessagesInbox');
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        automaticallyImplyLeading: !embedded,
        title: Text(l.messagesInboxTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: uid == null
          ? Center(child: Text(l.noChatsYet, style: TextStyle(color: c.textTertiary)))
          : ref.watch(myChatsProvider(uid)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(
                    child: Text(l.errorWithMessage(e),
                        style: const TextStyle(color: AppColors.error))),
                data: (chats) {
                  if (chats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l.noChatsYet,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.textTertiary, fontSize: 14, height: 1.5)),
                      ),
                    );
                  }
                  // Centered + width-capped, matching the other list screens
                  // under Mein Netzwerk — this used to have no width
                  // constraint and stretched full-width on desktop, and each
                  // row was a bare ListTile with no card treatment at all.
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ChatRow(chat: chats[i], myId: uid),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

// Same card shell (rounded 14px, bordered, hover glow) as _MyRequestTile in
// my_requests_screen.dart and _RequestCard in received_requests_screen.dart
// — this used to be a bare ListTile with a Divider between rows, the odd one
// out among the Mein Netzwerk / Nachrichten list screens.
class _ChatRow extends ConsumerStatefulWidget {
  final ChatModel chat;
  final String myId;
  const _ChatRow({required this.chat, required this.myId});

  @override
  ConsumerState<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends ConsumerState<_ChatRow> {
  bool _hovered = false;

  String _time(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day}.${t.month}.';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final otherId = widget.chat.otherParticipant(widget.myId);
    final company = ref.watch(companyByIdProvider(otherId)).valueOrNull;
    final name = (company?.name.isNotEmpty ?? false) ? company!.name : l.chatFallbackTitle;
    final unread = widget.chat.unreadFor(widget.myId);
    final hasUnread = unread > 0;
    // The chat doc itself carries no urgency signal — that lives on the
    // contact_requests doc (same id as the chat). Previously only visible
    // once you'd already opened the chat (see _CollabBanner); surfaced here
    // too so an urgent thread stands out in the inbox list itself.
    final urgent = ref.watch(contactRequestByIdProvider(widget.chat.id)).valueOrNull?.urgent ?? false;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: widget.chat.id,
              myCompanyId: widget.myId,
              otherCompanyId: otherId,
              otherCompanyName: name,
              postId: widget.chat.postId,
            ),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? AppColors.primary.withOpacity(0.4) : c.border,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      if (urgent) ...[
                        const Text('🔥', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w800,
                                fontSize: 14.5)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      widget.chat.lastMessage.isEmpty ? l.noMessagesYetShort : widget.chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: hasUnread ? c.textPrimary : c.textSecondary,
                          fontSize: 13,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_time(widget.chat.lastMessageAt),
                      style: TextStyle(
                          color: hasUnread ? AppColors.primary : c.textTertiary, fontSize: 11)),
                  const SizedBox(height: 4),
                  if (hasUnread)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text('$unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    )
                  else
                    const SizedBox(height: 15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
