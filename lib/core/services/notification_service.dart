import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

/// Notification records are entirely server-authored (Cloud Functions via the
/// Admin SDK) — this service never creates a notification doc, only reads
/// them and flips `read`, matching what firestore.rules permits the client.
class NotificationService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _fs.collection('notifications');

  /// All notifications addressed to [uid], newest first. Single-field query +
  /// client-side sort — same "no composite index needed" shape as myChats().
  Stream<List<NotificationModel>> myNotifications(String uid) {
    return _notifications.where('recipientId', isEqualTo: uid).snapshots().map((s) {
      final list = s.docs.map(NotificationModel.fromFirestore).toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Future<void> markRead(String id) async {
    try {
      await _notifications.doc(id).update({'read': true});
    } catch (_) {}
  }

  Future<void> markAllRead(List<NotificationModel> notifications) async {
    final unread = notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = _fs.batch();
    for (final n in unread) {
      batch.update(_notifications.doc(n.id), {'read': true});
    }
    try {
      await batch.commit();
    } catch (_) {}
  }
}
