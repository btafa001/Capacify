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
  final String type; // 'new_message' | 'new_contact_request' | 'verification_submitted' | 'content_flagged' | 'rating_submitted'
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
  final String requestId; // new_contact_request
  final bool urgent; // new_contact_request

  // Both new_message and new_contact_request are addressed to a regular
  // (non-admin) company and already have their own dedicated, real-time
  // surfacing — the chat's `unread` map, and the Received-Requests screen's
  // pending-count sidebar badge, respectively — so both are excluded here
  // the same way, rather than folding into the admin-events bell dropdown
  // (which every OTHER type is currently addressed only to admin uids for).
  bool get isAdminEvent => type != 'new_message' && type != 'new_contact_request';

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
    this.requestId = '',
    this.urgent = false,
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
      requestId: data['requestId'] ?? '',
      urgent: data['urgent'] as bool? ?? false,
    );
  }
}
