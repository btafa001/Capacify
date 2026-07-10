import 'package:cloud_firestore/cloud_firestore.dart';

/// A requester asking to be connected to an (anonymous) post's poster.
/// Doc id is deterministic: `{requesterCompanyId}_{postId}` — one request per
/// requester per post, and it lets the capacityOwners grant rule resolve the
/// request with a single get().
///
/// The requester writes only what they legitimately know: their own id/name,
/// non-identifying trust signals, an optional message, and the post's public
/// trade/workerCount. The poster's identity is NOT written by the requester.
///
/// status:
///   pending_review — unverified requester; founder screens before the poster
///                    sees it (spam protection).
///   pending        — verified requester (or founder-approved); the POSTER now
///                    sees it and may accept/decline.
///   granted        — accepted → contact released to the matched pair.
///   declined       — poster (or founder) declined; no reveal.
///   closed         — soft-deleted.
/// Poster identity to the requester is never displayed pre-`granted`. The
/// requester's identity to the poster is hidden in the UI pre-accept (the
/// poster's inbox shows only the trust signals + message below).
class ContactRequestModel {
  final String id;
  final String requesterCompanyId;
  final String requesterCompanyName;
  final String postId;
  final String trade;
  final int workerCount;
  final String message;
  final String status;
  final String? outcome; // null | matched | no_deal
  final String? posterCompanyId; // admin/poster-stamped
  final String? valueEstimate; // admin-only: hoch | mittel | niedrig
  // Requester trust signals (shown to the poster pre-accept without the name)
  final bool requesterVerified;
  final int requesterRatingSum;
  final int requesterRatingCount;
  final String requesterCity;
  final DateTime? createdAt;
  // Mutual "we worked together" confirmation on a granted connection. When BOTH
  // are true, a Cloud Function counts a completed collaboration for both
  // companies (+ a repeat if the pair has collaborated before). Trust signal +
  // CapacityOS data; mutual so neither side can inflate its own count.
  final bool collabRequester;
  final bool collabPoster;

  double get requesterRating =>
      requesterRatingCount > 0 ? requesterRatingSum / requesterRatingCount : 0.0;

  bool get collabConfirmed => collabRequester && collabPoster;

  ContactRequestModel({
    required this.id,
    required this.requesterCompanyId,
    required this.requesterCompanyName,
    required this.postId,
    required this.trade,
    required this.workerCount,
    this.message = '',
    required this.status,
    this.outcome,
    this.posterCompanyId,
    this.valueEstimate,
    this.requesterVerified = false,
    this.requesterRatingSum = 0,
    this.requesterRatingCount = 0,
    this.requesterCity = '',
    this.createdAt,
    this.collabRequester = false,
    this.collabPoster = false,
  });

  static String idFor(String requesterCompanyId, String postId) =>
      '${requesterCompanyId}_$postId';

  factory ContactRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContactRequestModel(
      id: doc.id,
      requesterCompanyId: data['requesterCompanyId'] ?? '',
      requesterCompanyName: data['requesterCompanyName'] ?? '',
      postId: data['postId'] ?? '',
      trade: data['trade'] ?? '',
      workerCount: data['workerCount'] ?? 0,
      message: data['message'] ?? '',
      status: data['status'] ?? 'pending',
      outcome: data['outcome'] as String?,
      posterCompanyId: data['posterCompanyId'] as String?,
      valueEstimate: data['valueEstimate'] as String?,
      requesterVerified: data['requesterVerified'] as bool? ?? false,
      requesterRatingSum: data['requesterRatingSum'] ?? 0,
      requesterRatingCount: data['requesterRatingCount'] ?? 0,
      requesterCity: data['requesterCity'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      collabRequester: data['collabRequester'] as bool? ?? false,
      collabPoster: data['collabPoster'] as bool? ?? false,
    );
  }

  /// Initial client-side create payload. `status` is set by the service based
  /// on the requester's verification (pending vs pending_review) — the rules
  /// enforce that an unverified requester can only create pending_review.
  Map<String, dynamic> toFirestoreCreate() {
    return {
      'requesterCompanyId': requesterCompanyId,
      'requesterCompanyName': requesterCompanyName,
      'postId': postId,
      'trade': trade,
      'workerCount': workerCount,
      'message': message,
      'status': status,
      'outcome': null,
      'requesterVerified': requesterVerified,
      'requesterRatingSum': requesterRatingSum,
      'requesterRatingCount': requesterRatingCount,
      'requesterCity': requesterCity,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
