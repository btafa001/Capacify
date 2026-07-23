import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import 'admin_provider.dart';
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
///
/// Gated on the account's CURRENT isAdmin status, not just on whose uid a
/// notification doc happens to be addressed to — admin fan-out docs are
/// never deleted, so an account that once had isAdmin (even briefly, e.g.
/// during initial setup) and later had it removed would otherwise keep
/// seeing, and being badge-counted for, admin events from back when it still
/// held the flag.
final unreadAdminNotificationsProvider =
    Provider.family<List<NotificationModel>, String>((ref, uid) {
  final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
  if (!isAdmin) return const [];
  final all = ref.watch(myNotificationsProvider(uid)).valueOrNull ?? [];
  return all.where((n) => n.isAdminEvent && !n.read).toList();
});

/// Personal event notifications addressed to this user — request accepted,
/// verification result, rating approved, and the pending/collaboration nudges.
/// Rendered in the bell's "Aktivität" section for the recipient. Unlike admin
/// events these are NEVER gated on isAdmin: a regular company only ever receives
/// its own personal docs (recipientId == uid), so the stream is already scoped.
/// new_message / new_contact_request are excluded — they surface via the chat
/// unread map and the Received-Requests badge instead.
final unreadPersonalNotificationsProvider =
    Provider.family<List<NotificationModel>, String>((ref, uid) {
  final all = ref.watch(myNotificationsProvider(uid)).valueOrNull ?? [];
  return all.where((n) => n.isPersonalEvent && !n.read).toList();
});
