import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_service.dart';
import '../models/chat_model.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// Live message stream for one chat thread.
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, chatId) {
  return ref.watch(chatServiceProvider).messages(chatId);
});

/// Live thread doc (unread / read receipts / typing state).
final chatDocProvider =
    StreamProvider.family<ChatModel?, String>((ref, chatId) {
  return ref.watch(chatServiceProvider).chatDoc(chatId);
});

/// A company's conversation list (the "Nachrichten" inbox).
final myChatsProvider =
    StreamProvider.family<List<ChatModel>, String>((ref, companyId) {
  return ref.watch(chatServiceProvider).myChats(companyId);
});

/// Total unread messages across all of a company's chats — drives the nav badge.
/// Derived from the existing inbox stream (no extra subscription).
final totalUnreadProvider = Provider.family<int, String>((ref, companyId) {
  final chats = ref.watch(myChatsProvider(companyId)).valueOrNull ?? [];
  return chats.fold<int>(0, (sum, c) => sum + c.unreadFor(companyId));
});
