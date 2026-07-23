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
  final String type;
  // Admin fan-out:  'verification_submitted' | 'content_flagged' | 'rating_submitted'
  // Personal:       'request_accepted' | 'verification_result' | 'rating_approved' |
  //                 'request_pending_nudge' | 'collab_nudge'
  // Surfaced elsewhere (not rendered as tiles): 'new_message' | 'new_contact_request'
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
  final String requestId; // new_contact_request / request_accepted / request_pending_nudge
  final String postId; // request_accepted only: opens the chat with full post context
  final bool urgent; // new_contact_request
  final String outcome; // verification_result only: 'verified' | 'rejected'
  final int rating; // rating_approved only: 1..5

  // Two disjoint families. Admin events fan out one doc per admin uid; personal
  // events are addressed to a single regular company and render in the bell for
  // that recipient. new_message and new_contact_request are in NEITHER set —
  // they already have dedicated real-time surfacing (the chat's `unread` map and
  // the Received-Requests pending badge), so the bell shows them there, not as
  // notification-doc tiles. (Previously isAdminEvent was `type != new_message &&
  // type != new_contact_request`, which mis-swept collab_nudge — and every future
  // personal type — into the admin-only bucket.)
  static const _adminTypes = {
    'verification_submitted',
    'content_flagged',
    'rating_submitted',
  };
  static const _personalTypes = {
    'request_accepted',
    'verification_result',
    'rating_approved',
    'request_pending_nudge',
    'collab_nudge',
  };
  bool get isAdminEvent => _adminTypes.contains(type);
  bool get isPersonalEvent => _personalTypes.contains(type);

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
    this.postId = '',
    this.urgent = false,
    this.outcome = '',
    this.rating = 0,
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
      postId: data['postId'] ?? '',
      urgent: data['urgent'] as bool? ?? false,
      outcome: data['outcome'] ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
    );
  }
}
