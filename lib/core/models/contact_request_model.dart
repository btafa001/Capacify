import 'package:cloud_firestore/cloud_firestore.dart';

/// A requester asking to be connected to an (anonymous) post's poster.
/// Doc id is deterministic: `{requesterCompanyId}_{postId}` — one request per
/// requester per post, and it lets the capacityOwners grant rule resolve the
/// request with a single get().
///
/// The requester writes only what they legitimately know: their own id/name,
/// non-identifying trust signals, an optional message, and the post's public
/// trade/workerCount. The poster's identity is NOT written by the requester
/// (except posterCompanyId — see toFirestoreCreate — which the requester
/// copies from the post's own already-public field for visible/discreet
/// posts, never invents).
///
/// status:
///   pending  — awaiting the poster's Accept/Decline. Only reachable for an
///              `anonymous`-mode post (see CapacityModel.visibilityMode) —
///              that's the only mode keeping this gate, since its whole
///              point (hiding from a competitor) would be defeated by an
///              instant reveal on message.
///   granted  — contact released to the matched pair. Reached either via the
///              poster's deliberate Accept (anonymous posts), OR created
///              already-granted at message time (visible/discreet posts —
///              see ContactRequestService.requestContact).
///   declined — poster declined; no reveal.
///   closed   — soft-deleted.
/// For an anonymous-mode post: poster identity to the requester is never
/// displayed pre-`granted`, and the requester's identity to the poster is
/// hidden pre-accept (the poster's inbox shows only trust signals + message).
/// For visible/discreet posts, the poster's identity was already public on
/// the post itself before any request existed.
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
  // Requester-flagged urgency ("ich brauche schnell eine Antwort") — sorts
  // ahead of normal pending requests in the poster's inbox and escalates the
  // onNewContactRequest Cloud Function notification to an immediate email,
  // not just a push. Self-reported, not verified — same honesty framing as
  // the rest of this model; the fix for abuse is the same per-account
  // throttle that already caps posts/messages generally, not a separate gate.
  final bool urgent;
  // Set server-side by enforceContactRequestModeration when `message` matches
  // the blocked-words list — admin-visibility only (see functions/index.js);
  // the client never writes this and there's no public feed to hide it from,
  // so unlike capacities/companies it doesn't gate anything on its own.
  final bool contentFlagged;
  // CapacityOS readiness — what actually happened, captured at confirm time,
  // replacing the boolean-only "we worked together" with real outcome data.
  // Optional (either confirmer may set them; simplest useful semantics —
  // whoever writes them first wins, no reconciliation between two reports).
  final int? actualCrewSize;
  final int? actualDurationDays;
  // Re-engagement signal for my_capacities_screen.dart's "N neue Anfragen"
  // pull-back badge — a granted-but-unseen request (visible/discreet posts
  // are never `pending`, so that count alone would permanently read 0 for
  // them). Stamped true by ChatScreen the same way it already stamps
  // chat-level read state on open (see chat_service.dart's markRead).
  final bool seenByPoster;

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
    this.urgent = false,
    this.contentFlagged = false,
    this.actualCrewSize,
    this.actualDurationDays,
    this.seenByPoster = false,
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
      urgent: data['urgent'] as bool? ?? false,
      contentFlagged: data['contentFlagged'] as bool? ?? false,
      actualCrewSize: data['actualCrewSize'] as int?,
      actualDurationDays: data['actualDurationDays'] as int?,
      seenByPoster: data['seenByPoster'] as bool? ?? false,
    );
  }

  /// Initial client-side create payload. `status` is set by
  /// ContactRequestService.requestContact — 'pending' for an anonymous-mode
  /// post, or 'granted' (with posterCompanyId set) for an instant auto-grant
  /// on a visible/discreet post; firestore.rules verifies the auto-grant
  /// branch against the POST's own stored visibilityMode, never trusting
  /// this client-supplied status/posterCompanyId pair on its own.
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
      if (posterCompanyId != null) 'posterCompanyId': posterCompanyId,
      'requesterVerified': requesterVerified,
      'requesterRatingSum': requesterRatingSum,
      'requesterRatingCount': requesterRatingCount,
      'requesterCity': requesterCity,
      'urgent': urgent,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
