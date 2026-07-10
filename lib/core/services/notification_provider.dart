import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// All notifications addressed to [uid] (messages + admin events combined).
final myNotificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, uid) {
  return ref.watch(notificationServiceProvider).myNotifications(uid);
});

/// Admin-only event notifications (verification/flag/rating), excluding
/// `new_message` — the bell's Messages section already has its own real-time,
/// cross-device unread counter (chat doc's `unread` map), so folding
/// new_message notification docs into this count too would double-count.
final unreadAdminNotificationsProvider =
    Provider.family<List<NotificationModel>, String>((ref, uid) {
  final all = ref.watch(myNotificationsProvider(uid)).valueOrNull ?? [];
  return all.where((n) => n.isAdminEvent && !n.read).toList();
});
