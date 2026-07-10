import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/chat_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/chat_provider.dart';
import '../../../core/services/company_provider.dart';
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
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chats.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: c.border, indent: 72),
                    itemBuilder: (_, i) => _ChatRow(chat: chats[i], myId: uid),
                  );
                },
              ),
    );
  }
}

class _ChatRow extends ConsumerWidget {
  final ChatModel chat;
  final String myId;
  const _ChatRow({required this.chat, required this.myId});

  String _time(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day}.${t.month}.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final otherId = chat.otherParticipant(myId);
    final company = ref.watch(companyByIdProvider(otherId)).valueOrNull;
    final name = (company?.name.isNotEmpty ?? false) ? company!.name : l.chatFallbackTitle;
    final unread = chat.unreadFor(myId);
    final hasUnread = unread > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withOpacity(0.15),
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: c.textPrimary,
              fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w800,
              fontSize: 14.5)),
      subtitle: Text(
        chat.lastMessage.isEmpty ? l.noMessagesYetShort : chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: hasUnread ? c.textPrimary : c.textSecondary,
            fontSize: 13,
            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_time(chat.lastMessageAt),
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            myCompanyId: myId,
            otherCompanyId: otherId,
            otherCompanyName: name,
            postId: chat.postId,
          ),
        ),
      ),
    );
  }
}
