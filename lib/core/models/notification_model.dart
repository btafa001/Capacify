import 'package:cloud_firestore/cloud_firestore.dart';

/// A single notification event for one recipient. Always server-authored
/// (Cloud Functions via the Admin SDK, which bypasses rules entirely) —
/// the client's only legal write is flipping `read` to true on its own doc
/// (see firestore.rules). Admin-fan-out events (verification/flag/rating)
/// write one doc per admin uid rather than one shared doc, so each admin's
/// read state is independent.
class NotificationModel {
  final String id;
  final String recipientId;
  final String type; // 'new_message' | 'verification_submitted' | 'content_flagged' | 'rating_submitted'
  final bool read;
  final DateTime? createdAt;

  // Rendering + tap-to-navigate payload. Kept as explicit fields (not a
  // free-form map) per this codebase's plain-model convention — which
  // fields are populated depends on `type`. The bell renders fully
  // localized copy from these via AppLocalizations; nothing here is
  // pre-rendered text.
  final String chatId; // new_message
  final String companyId; // verification_submitted / content_flagged (company) / rating_submitted (rated company)
  final String companyName; // denormalized display name for the above
  final String ratingId; // rating_submitted
  final String capacityId; // content_flagged (capacity)
  final String contentType; // content_flagged only: 'capacity' | 'company'

  bool get isAdminEvent => type != 'new_message';

  NotificationModel({
    required this.id,
    required this.recipientId,
    required this.type,
    this.read = false,
    this.createdAt,
    this.chatId = '',
    this.companyId = '',
    this.companyName = '',
    this.ratingId = '',
    this.capacityId = '',
    this.contentType = '',
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      recipientId: data['recipientId'] ?? '',
      type: data['type'] ?? '',
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      chatId: data['chatId'] ?? '',
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      ratingId: data['ratingId'] ?? '',
      capacityId: data['capacityId'] ?? '',
      contentType: data['contentType'] ?? '',
    );
  }
}
