import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/capacity_model.dart';
import '../models/company_model.dart';
import '../models/contact_request_model.dart';

/// Thrown when a company tries to unlock a post with no Vermittlungen left.
class InsufficientCreditsException implements Exception {
  const InsufficientCreditsException();
}

/// Contact requests — the FREE, message-first connection flow (no credits,
/// no payment). requestContact() always creates a 'pending' request carrying
/// the requester's message + anonymized trust signals; the poster is
/// notified and Accepts/Declines it. Accepting reveals both identities and
/// opens a chat (see chat_screen.dart's _CollabBanner for the post-connection
/// "we worked together" confirmation).
class ContactRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('contact_requests');
  CollectionReference<Map<String, dynamic>> get _credits =>
      _firestore.collection('credits');

  // ─── Requester ───

  /// Send a FREE first message to a post's poster (launch phase — no credit,
  /// no payment). For an `anonymous`-mode post, creates a `pending` request —
  /// the poster is notified and Accepts → both identities reveal and a chat
  /// opens. For a `visible`/`discreet`-mode post, the post's identity was
  /// already public, so the request is created already `granted` — instant
  /// reveal, no Accept step (firestore.rules verifies this branch against the
  /// POST's own stored visibilityMode, never trusting this client on its own).
  /// Returns the resulting status ('pending' | 'granted'). No-op (returns the
  /// existing status) if a request already exists for this pair.
  Future<String> requestContact({
    required CapacityModel post,
    required CompanyModel requester,
    String message = '',
    bool urgent = false,
  }) async {
    final id = ContactRequestModel.idFor(requester.id, post.id);
    final existing = await _col.doc(id).get();
    if (existing.exists) {
      return (existing.data()?['status'] as String?) ?? 'pending';
    }

    final autoGrant = post.visibilityMode != CapacityVisibilityMode.anonymous
        && post.posterCompanyId != null;

    final model = ContactRequestModel(
      id: id,
      requesterCompanyId: requester.id,
      requesterCompanyName: requester.name,
      postId: post.id,
      trade: post.trade,
      workerCount: post.workerCount,
      message: message.trim(),
      status: autoGrant ? 'granted' : 'pending',
      posterCompanyId: autoGrant ? post.posterCompanyId : null,
      requesterVerified: requester.isVerified,
      requesterRatingSum: requester.ratingSum,
      requesterRatingCount: requester.ratingCount,
      requesterCity: requester.city,
      urgent: urgent,
    );
    await _col.doc(id).set(model.toFirestoreCreate());
    return model.status;
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
  ///
  /// Runs as a transaction (rather than a bare FieldValue.increment) because
  /// the resulting average also needs to be pushed onto the poster's own
  /// capacity CARDS (see _syncResponseStatToPosts) — the increment alone is
  /// opaque client-side, so the actual post-increment totals are needed here
  /// to compute the same avgResponseHours the CompanyModel getter derives.
  Future<void> _recordResponseTime(
      String posterCompanyId, DateTime? createdAt) async {
    if (createdAt == null) return;
    final ms = DateTime.now().difference(createdAt).inMilliseconds;
    if (ms <= 0) return;
    try {
      final companyRef = _firestore.collection('companies').doc(posterCompanyId);
      final avgHours = await _firestore.runTransaction<int?>((tx) async {
        final snap = await tx.get(companyRef);
        final prevCount = (snap.data()?['responseCount'] as num?)?.toInt() ?? 0;
        final prevSumMs = (snap.data()?['responseSumMs'] as num?)?.toInt() ?? 0;
        final newCount = prevCount + 1;
        final newSumMs = prevSumMs + ms;
        tx.update(companyRef, {
          'responseCount': newCount,
          'responseSumMs': newSumMs,
        });
        // Mirrors CompanyModel.avgResponseHours exactly (>=3 samples, min 1h).
        if (newCount < 3) return null;
        final hours = (newSumMs / newCount / (1000 * 60 * 60)).ceil();
        return hours < 1 ? 1 : hours;
      });
      await _syncResponseStatToPosts(posterCompanyId, avgHours);
    } catch (_) {}
  }

  /// Pushes the poster's updated responsiveness onto every one of their own
  /// active posts (posterAvgResponseHours) — the anonymized capacity CARD is
  /// the actual decision point for "who do I contact," and for an anonymized
  /// post the poster's company profile (and thus this signal) isn't visible
  /// there at all pre-contact. Mirrors the existing posterVerified/
  /// posterRatingSum sync pattern in CapacityService.updateCompanyNameOnAllPosts,
  /// scoped to just this one field. Best-effort, batched, capped defensively.
  Future<void> _syncResponseStatToPosts(String posterCompanyId, int? avgHours) async {
    try {
      final owned = await _firestore
          .collection('capacityOwners')
          .where('posterCompanyId', isEqualTo: posterCompanyId)
          .limit(500)
          .get();
      if (owned.docs.isEmpty) return;
      // Banded before it touches the public post — an exact hour figure is one
      // more field an anonymous post can be joined on (see
      // CapacityModel.bandResponseHours).
      final banded = CapacityModel.bandResponseHours(avgHours);
      final batch = _firestore.batch();
      for (final doc in owned.docs) {
        batch.update(_firestore.collection('capacities').doc(doc.id), {
          'posterAvgResponseHours': banded ?? FieldValue.delete(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Mark "we worked together" from one side of a granted connection. When
  /// BOTH sides have confirmed, a Cloud Function (onCollabConfirmed) counts the
  /// completed collaboration for both companies. Mutual, so no self-inflation.
  ///
  /// [actualCrewSize]/[actualDurationDays] are optional CapacityOS outcome
  /// data (see firestore.rules) — what actually happened, not just the
  /// boolean. Either confirmer may supply them; whoever writes first wins,
  /// no attempt to reconcile two different reports.
  Future<void> confirmCollaboration({
    required String requestId,
    required bool asPoster,
    int? actualCrewSize,
    int? actualDurationDays,
  }) async {
    await _col.doc(requestId).update({
      (asPoster ? 'collabPoster' : 'collabRequester'): true,
      if (actualCrewSize != null) 'actualCrewSize': actualCrewSize,
      if (actualDurationDays != null) 'actualDurationDays': actualDurationDays,
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

  /// The poster opening the chat marks their granted request "seen" — clears
  /// it from my_capacities_screen.dart's "N neue Anfragen" pull-back count.
  /// False→true only, mirrors the pattern already used for contentFlagged.
  Future<void> markSeenByPoster(String requestId) async {
    try {
      await _col.doc(requestId).update({'seenByPoster': true});
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
        // Pending (needs the poster's action) always above granted; within
        // pending, urgent-flagged requests sort first — the fast lane a slow
        // response time (Part 2 of the audit) is most costly for.
        if (a.status != b.status) return a.status == 'pending' ? -1 : 1;
        if (a.status == 'pending' && a.urgent != b.urgent) {
          return a.urgent ? -1 : 1;
        }
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
