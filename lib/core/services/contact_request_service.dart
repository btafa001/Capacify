import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/capacity_model.dart';
import '../models/company_model.dart';
import '../models/contact_request_model.dart';

/// Thrown when a company tries to unlock a post with no Vermittlungen left.
class InsufficientCreditsException implements Exception {
  const InsufficientCreditsException();
}

/// Contact requests — now a **credit-based Vermittlung**. Spending one credit
/// unlocks the poster's identity + contact + chat *instantly*; the poster is
/// notified after the fact rather than asked to accept.
///
/// Routing (enforced in firestore.rules):
///   verified requester   → status 'granted' created in ONE batch that also
///                          decrements the requester's credits doc. The rules
///                          only allow a 'granted' create when a credit is
///                          simultaneously spent (getAfter), so a client can't
///                          self-grant free reveals.
///   unverified requester → status 'pending_review' (no credit spent yet); the
///                          founder screens it, and approval grants + spends.
class ContactRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('contact_requests');
  CollectionReference<Map<String, dynamic>> get _credits =>
      _firestore.collection('credits');

  // ─── Requester ───

  /// Send a FREE first message to a post's poster (launch phase — no credit,
  /// no payment). Creates a `pending` request carrying the requester's message
  /// + anonymized trust signals. The poster is notified and Accepts → both
  /// identities reveal and a chat opens. No-op if a request already exists.
  Future<void> requestContact({
    required CapacityModel post,
    required CompanyModel requester,
    String message = '',
  }) async {
    final id = ContactRequestModel.idFor(requester.id, post.id);
    final existing = await _col.doc(id).get();
    if (existing.exists) return;

    final model = ContactRequestModel(
      id: id,
      requesterCompanyId: requester.id,
      requesterCompanyName: requester.name,
      postId: post.id,
      trade: post.trade,
      workerCount: post.workerCount,
      message: message.trim(),
      status: 'pending',
      requesterVerified: requester.isVerified,
      requesterRatingSum: requester.ratingSum,
      requesterRatingCount: requester.ratingCount,
      requesterCity: requester.city,
    );
    await _col.doc(id).set(model.toFirestoreCreate());
  }

  /// The POSTER accepts an incoming message → reveals both identities and opens
  /// the chat. Stamps the poster id so the requester's side + chat can resolve
  /// it. The capacityOwners sidecar becomes readable to the requester on
  /// `granted` (firestore.rules), which is what performs the actual reveal.
  Future<void> acceptRequest({
    required String requestId,
    required String posterCompanyId,
    DateTime? requestCreatedAt,
  }) async {
    await _col.doc(requestId).update({
      'status': 'granted',
      'posterCompanyId': posterCompanyId,
    });
    await _recordResponseTime(posterCompanyId, requestCreatedAt);
  }

  /// The POSTER declines an incoming message — no reveal. Still counts as a
  /// response for the responsiveness signal.
  Future<void> declineRequest(
    String requestId, {
    String? posterCompanyId,
    DateTime? requestCreatedAt,
  }) async {
    await _col.doc(requestId).update({'status': 'declined'});
    if (posterCompanyId != null) {
      await _recordResponseTime(posterCompanyId, requestCreatedAt);
    }
  }

  /// Records how long the poster took to respond to a request onto their own
  /// company doc as a running sum+count (→ "Antwortet meist in ~Xh", a trust
  /// signal + a CapacityOS data point). The poster owns this doc, and the
  /// owner-update rule permits these non-pinned fields, so no batch/rule change
  /// is needed. Best-effort: a failure must never block the accept/decline.
  Future<void> _recordResponseTime(
      String posterCompanyId, DateTime? createdAt) async {
    if (createdAt == null) return;
    final ms = DateTime.now().difference(createdAt).inMilliseconds;
    if (ms <= 0) return;
    try {
      await _firestore.collection('companies').doc(posterCompanyId).update({
        'responseCount': FieldValue.increment(1),
        'responseSumMs': FieldValue.increment(ms),
      });
    } catch (_) {}
  }

  /// Mark "we worked together" from one side of a granted connection. When
  /// BOTH sides have confirmed, a Cloud Function (onCollabConfirmed) counts the
  /// completed collaboration for both companies. Mutual, so no self-inflation.
  Future<void> confirmCollaboration({
    required String requestId,
    required bool asPoster,
  }) async {
    await _col.doc(requestId).update({
      (asPoster ? 'collabPoster' : 'collabRequester'): true,
    });
  }

  /// After a grant, the requester can read the (now-unlocked) sidecar and stamp
  /// the resolved poster id onto their request — used for the poster's log,
  /// analytics, and opening the chat. Rules permit this single field on a
  /// requester's own granted request.
  Future<void> stampPoster({
    required String requestId,
    required String posterCompanyId,
  }) async {
    try {
      await _col.doc(requestId).update({'posterCompanyId': posterCompanyId});
    } catch (_) {}
  }

  Stream<List<ContactRequestModel>> myRequests(String requesterCompanyId) {
    return _col
        .where('requesterCompanyId', isEqualTo: requesterCompanyId)
        .snapshots()
        .map(_sortedNewest);
  }

  /// Stream one request by its doc id. Used by the chat (chatId == requestId)
  /// to drive the collaboration-confirm banner. Both parties may read it.
  Stream<ContactRequestModel?> requestById(String requestId) {
    return _col.doc(requestId).snapshots().map(
        (d) => d.exists ? ContactRequestModel.fromFirestore(d) : null);
  }

  Stream<ContactRequestModel?> myRequestForPost({
    required String requesterCompanyId,
    required String postId,
  }) {
    final id = ContactRequestModel.idFor(requesterCompanyId, postId);
    return _col.doc(id).snapshots().map(
        (d) => d.exists ? ContactRequestModel.fromFirestore(d) : null);
  }

  Future<void> setOutcome({
    required String requestId,
    required String outcome, // 'matched' | 'no_deal' | 'open'
  }) async {
    await _col.doc(requestId).update({'outcome': outcome});
  }

  // ─── Poster (Vermittlungen to their posts — a log, no action needed) ───

  /// Incoming messages on the poster's own posts — `pending` (awaiting the
  /// poster's Accept/Decline) and `granted` (already connected). `in` caps at
  /// 10 postIds, so chunk. Pending sort first (they need action), then newest.
  Stream<List<ContactRequestModel>> receivedRequests(List<String> myPostIds) {
    if (myPostIds.isEmpty) {
      return Stream.value(<ContactRequestModel>[]);
    }
    final chunk = myPostIds.take(10).toList();
    return _col.where('postId', whereIn: chunk).snapshots().map((s) {
      final list = s.docs
          .map((d) => ContactRequestModel.fromFirestore(d))
          .where((r) => r.status == 'pending' || r.status == 'granted')
          .toList();
      list.sort((a, b) {
        // Pending (needs the poster's action) always above granted.
        if (a.status != b.status) return a.status == 'pending' ? -1 : 1;
        return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });
      return list;
    });
  }

  // ─── Founder / admin ───

  Stream<List<ContactRequestModel>> allRequests() {
    return _col.snapshots().map(_sortedNewest);
  }

  /// Founder approves a screened (pending_review) request → grants it and spends
  /// one of the requester's Vermittlungen (admin writes bypass the getAfter
  /// rule). If the requester is out of credits the grant proceeds without a
  /// debit rather than blocking the connection.
  Future<void> approveGrant({
    required String requestId,
    required String requesterCompanyId,
    String? posterCompanyId,
  }) async {
    final walletRef = _credits.doc(requesterCompanyId);
    final wSnap = await walletRef.get();
    final remaining = (wSnap.data()?['remaining'] as num?)?.toInt() ?? 0;
    final batch = _firestore.batch();
    if (wSnap.exists && remaining > 0) {
      batch.update(walletRef, {
        'remaining': remaining - 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_col.doc(requestId), {
      'status': 'granted',
      if (posterCompanyId != null) 'posterCompanyId': posterCompanyId,
    });
    await batch.commit();
  }

  /// Founder rejects a screened request (spam / abuse) — no reveal, no debit.
  Future<void> reject(String requestId) async {
    await _col.doc(requestId).update({'status': 'declined'});
  }

  List<ContactRequestModel> _sortedNewest(QuerySnapshot<Map<String, dynamic>> s) {
    final list =
        s.docs.map((d) => ContactRequestModel.fromFirestore(d)).toList();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  }
}
