import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/company_model.dart';
import '../models/company_rating_model.dart';

/// Thrown by uploadLogo() for a file that fails the client-side pre-check —
/// mirrors what storage.rules actually enforces (2 MB cap, image/* content
/// type), just surfaced instantly instead of after a round trip to Storage.
class InvalidLogoFileException implements Exception {
  final String message;
  const InvalidLogoFileException(this.message);
}

class CompanyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new company
  Future<void> createCompany(CompanyModel company) async {
    await _firestore
        .collection('companies')
        .doc(company.id)
        .set(company.toFirestore());
  }

  // Update existing company
  Future<void> updateCompany(CompanyModel company) async {
    await _firestore
        .collection('companies')
        .doc(company.id)
        .update(company.toFirestoreForUpdate());
  }

  /// Toggle the retention-email opt-in (match alerts + weekly digest). A single
  /// owner-writable field, kept out of the full profile-save path so it can't
  /// be clobbered by a stale model.
  Future<void> setEmailOptIn(String companyId, bool value) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .update({'emailOptIn': value});
  }

  /// Uploads a new company logo and returns its public download URL.
  ///
  /// Goes through the uploadCompanyLogo Cloud Function rather than writing to
  /// Storage directly. Direct client writes hit a real, confirmed FlutterFire
  /// Web bug (flutterfire#12607): Reference.putData() on Flutter Web doesn't
  /// reliably transmit SettableMetadata (contentType) with the upload, which
  /// made a storage.rules content-type check reject every web upload
  /// outright. Even after dropping that check, uploads kept failing —
  /// evidence the same unreliability likely also affects request.resource.size
  /// (or some other client-side write path), not just contentType. Rather
  /// than keep chasing which piece of metadata Flutter Web fails to send this
  /// time, this hands the actual bytes to a trusted Cloud Function, which
  /// writes via the Admin SDK (bypasses Storage rules entirely — no client
  /// metadata transmission involved at all). storage.rules now denies ALL
  /// client writes to this path; only this function can write here.
  ///
  /// Calls the function via a plain HTTP POST (package:http) rather than
  /// cloud_functions' httpsCallable — the callable SDK tries to attach an App
  /// Check token to every call, and a broken App Check config made that
  /// attachment step fail and take the whole upload down with it, even with
  /// App Check enforcement off. A raw POST with the Firebase ID token as a
  /// Bearer header sidesteps that path entirely; the function verifies the
  /// token by hand instead of relying on onCall's req.auth.
  Future<String> uploadLogo({
    required Uint8List bytes,
    required String contentType,
  }) async {
    // Client resizes to max 512px before this ever runs (see
    // company_profile_screen.dart._pickAndUploadLogo), so a real photo
    // shouldn't come anywhere near this — it's a backstop, not the primary
    // size control. Kept small on purpose: storage isn't unlimited.
    if (bytes.lengthInBytes >= 1024 * 1024) {
      throw const InvalidLogoFileException('Die Datei ist größer als 1 MB.');
    }
    // Fast, friendly pre-check only. The Cloud Function is the real gate: it
    // sniffs the actual bytes and rejects anything that isn't a genuine raster
    // image (SVG included), so a spoofed contentType here changes nothing.
    const allowedTypes = {
      'image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif',
    };
    if (!allowedTypes.contains(contentType.toLowerCase())) {
      throw const InvalidLogoFileException(
          'Bitte wählen Sie ein PNG-, JPG-, WEBP- oder GIF-Bild.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const InvalidLogoFileException('Bitte melden Sie sich erneut an.');
    }
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.https('europe-west3-capacify-mvp.cloudfunctions.net', '/uploadCompanyLogo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'base64Data': base64Encode(bytes), 'contentType': contentType}),
    );
    if (response.statusCode != 200) {
      throw Exception('uploadCompanyLogo ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Persists the logo URL alone — same "single owner-writable field, kept
  /// out of the full profile-save path" pattern as setEmailOptIn above, so an
  /// upload can't be clobbered by (or itself clobber) an unrelated in-progress
  /// profile edit.
  Future<void> updateLogoUrl(String companyId, String logoUrl) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .update({'logoUrl': logoUrl});
  }

  // Get company by owner ID
  Future<CompanyModel?> getCompanyByOwner(String ownerId) async {
    final query = await _firestore
        .collection('companies')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return CompanyModel.fromFirestore(query.docs.first);
  }

  // Single company by ID — for inline rating badges on capacity/company cards
  Stream<CompanyModel?> getCompanyStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((doc) => doc.exists ? CompanyModel.fromFirestore(doc) : null);
  }

  // Get all companies for directory — excludes ones whose name/description
  // is flagged and awaiting admin review, and ones an admin has suspended.
  Stream<List<CompanyModel>> getCompanies() {
    return _firestore
        .collection('companies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CompanyModel.fromFirestore(doc))
            .where((c) => !c.contentFlagged && !c.suspended)
            .toList());
  }

  // Search companies by trade or city
  Stream<List<CompanyModel>> searchCompanies({
    String? trade,
    String? city,
  }) {
    Query query = _firestore.collection('companies');

    if (trade != null && trade.isNotEmpty) {
      query = query.where('trades', arrayContains: trade);
    }
    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }

    return query
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CompanyModel.fromFirestore(doc))
            .toList());
  }

  // ─── RATINGS ───

  /// Creates or updates the rater's rating for a company. The rater ONLY ever
  /// writes their own companyRatings doc (in 'pending' state) — it never
  /// touches the company's ratingSum/ratingCount aggregate. Those are
  /// admin-only and are recomputed from the approved reviews on the next
  /// moderation action (see AdminService._recomputeRatingAggregate). This is
  /// what makes the score tamper-proof: a client physically cannot write the
  /// aggregate (firestore.rules pins ratingSum/ratingCount for every
  /// non-admin writer), so scores can't be forged for self or competitors.
  ///
  /// Editing an already-approved rating drops it back to 'pending'; its old
  /// contribution lingers in the denormalized number only until an admin next
  /// moderates any rating for that company, at which point the aggregate is
  /// recomputed exactly. That brief staleness is not exploitable (you still
  /// can't manufacture an approved rating).
  ///
  /// [viaRequestId] must be a granted contact_request that actually connects
  /// the rater and rated company (see findGrantedRequestId) — firestore.rules
  /// independently re-verifies this via isGrantedConnectionBetween(), so it
  /// can't be forged by passing an arbitrary id.
  Future<void> submitRating({
    required String companyId,
    required String raterUserId,
    required String raterCompanyName,
    required int rating,
    required String comment,
    required String viaRequestId,
  }) async {
    final ratingRef =
        _firestore.collection('companyRatings').doc('${raterUserId}_$companyId');

    final existingSnap = await ratingRef.get();
    final companySnap =
        await _firestore.collection('companies').doc(companyId).get();
    final ratedCompanyName = companySnap.data()?['name'] ?? '';

    final batch = _firestore.batch();
    batch.set(ratingRef, {
      'raterUserId': raterUserId,
      'raterCompanyName': raterCompanyName,
      'companyId': companyId,
      'ratedCompanyName': ratedCompanyName,
      'rating': rating,
      'comment': comment,
      'status': 'pending',
      'viaRequestId': viaRequestId,
      'createdAt': existingSnap.exists
          ? (existingSnap.data()?['createdAt'])
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Daily throttle — only on a genuine first rating for this company (an
    // edit re-uses the same doc, not a new one, so it shouldn't cost quota
    // twice). Previously uncapped entirely (see ratingCounts in
    // firestore.rules).
    if (!existingSnap.exists) {
      final today = _todayStr();
      final countRef = _firestore.collection('ratingCounts').doc(raterUserId);
      final countSnap = await countRef.get();
      final sameDay = countSnap.exists && countSnap.data()?['day'] == today;
      final newCount = sameDay ? ((countSnap.data()?['count'] ?? 0) as int) + 1 : 1;
      batch.set(countRef, {'day': today, 'count': newCount});
    }

    await batch.commit();
  }

  // UTC 'YYYY-MM-DD' — matches the server request.time used by the throttle
  // rule (same helper as CapacityService._todayStr).
  String _todayStr() {
    final n = DateTime.now().toUtc();
    final mm = n.month.toString().padLeft(2, '0');
    final dd = n.day.toString().padLeft(2, '0');
    return '${n.year}-$mm-$dd';
  }

  /// How many companies list this one as their referrer (see
  /// AuthService._referrerFromUrl / CompanyModel.referredBy) — shown to the
  /// inviter as "Empfehlungen: Nx" in Settings. A single billed count()
  /// aggregate, same pattern as CapacityService.countOwnerPosts.
  Future<int> countReferrals(String companyId) async {
    try {
      final agg = await _firestore
          .collection('companies')
          .where('referredBy', isEqualTo: companyId)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Finds a granted contact_request connecting the two companies, in either
  /// direction (myCompanyId as the requester on one of otherCompanyId's
  /// posts, or vice versa) — used to gate the "Bewerten" button on a real
  /// collaboration rather than any two accounts (Part 9 of the audit: any
  /// account could rate any other with no proof they ever interacted).
  ///
  /// This is a UI convenience only — it decides what the rating button
  /// offers. The actual security boundary is firestore.rules'
  /// isGrantedConnectionBetween(), which independently re-checks whatever id
  /// is returned here before allowing the rating write.
  Future<String?> findGrantedRequestId({
    required String myCompanyId,
    required String otherCompanyId,
  }) async {
    // Fails CLOSED. This only decides whether the "Bewerten" button is offered;
    // firestore.rules' isGrantedConnectionBetween() is the real gate, re-run on
    // the rating write. So ANY read error here resolves to "no connection"
    // (button disabled) rather than propagating — an unhandled error out of
    // this lookup is what surfaced as the grey overlay on the detail dialog, so
    // swallowing it makes the non-admin path drive the exact same clean
    // "null" state the admin path already does.
    try {
      // Direction 1: I requested one of THEIR posts and they granted it. Every
      // doc this query returns is my OWN request (requesterCompanyId == me), so
      // the contact_requests read rule's requester branch authorizes the whole
      // list at once.
      final asRequester = await _firestore
          .collection('contact_requests')
          .where('requesterCompanyId', isEqualTo: myCompanyId)
          .where('status', isEqualTo: 'granted')
          .get();
      for (final doc in asRequester.docs) {
        final postId = doc.data()['postId'] as String?;
        if (postId == null) continue;
        final owner =
            await _firestore.collection('capacityOwners').doc(postId).get();
        if (owner.exists &&
            owner.data()?['posterCompanyId'] == otherCompanyId) {
          return doc.id;
        }
      }

      // Direction 2: THEY requested one of MY posts and I granted it.
      //
      // This must NOT be done by querying `where requesterCompanyId ==
      // otherCompanyId` — I am not the requester on those docs, so
      // firestore.rules only authorizes them one-by-one via the poster branch
      // (get(capacityOwners[postId]).posterCompanyId == me). Such a query also
      // sweeps in the other company's granted requests to OTHER posters' posts,
      // which I can't read, and Firestore then fails the ENTIRE query with
      // permission-denied rather than returning a subset. That denial was the
      // source of the grey overlay covering the company detail dialog for every
      // non-admin viewer (admins slipped past it via the rules' isAdmin()
      // branch, which is why it never reproduced on the admin account).
      //
      // A per-post deterministic-id get (`{otherCompanyId}_{postId}`) is NOT a
      // valid shortcut either: the read rule only lets me probe a NON-existent
      // request whose id starts with my OWN uid, so a miss on a post they never
      // requested is itself denied. Querying MY posts by postId is the only
      // shape that dodges both traps — it returns only existing docs on posts I
      // own, each authorized by the poster branch — the same shape as
      // ContactRequestService.receivedRequests.
      final myOwners = await _firestore
          .collection('capacityOwners')
          .where('posterCompanyId', isEqualTo: myCompanyId)
          .limit(500)
          .get();
      final myPostIds = myOwners.docs.map((d) => d.id).toList();
      for (var i = 0; i < myPostIds.length; i += 10) {
        final end = (i + 10 < myPostIds.length) ? i + 10 : myPostIds.length;
        final chunk = myPostIds.sublist(i, end); // whereIn caps at 10.
        final onMyPosts = await _firestore
            .collection('contact_requests')
            .where('postId', whereIn: chunk)
            .get();
        for (final doc in onMyPosts.docs) {
          final data = doc.data();
          if (data['status'] == 'granted' &&
              data['requesterCompanyId'] == otherCompanyId) {
            return doc.id;
          }
        }
      }
      return null;
    } catch (_) {
      // Fail closed — see the method's opening comment.
      return null;
    }
  }

  /// Withdraws the rater's own rating. Only deletes the review doc — it does
  /// NOT touch the company aggregate (which is admin-only and non-writable by
  /// the client). If the withdrawn rating had been approved, the denormalized
  /// score is corrected the next time an admin moderates a rating for that
  /// company (recompute-from-approved). Admins deleting a rating should use
  /// AdminService.deleteRatingAndRecompute so the aggregate updates at once.
  Future<void> deleteRating({
    required String ratingId,
    required String companyId,
  }) async {
    await _firestore.collection('companyRatings').doc(ratingId).delete();
  }

  /// Public-facing reviews list — only approved ratings are ever shown.
  /// Sorts client-side (review counts per company are small) so this
  /// doesn't need a Firestore composite index for companyId+status+orderBy.
  Stream<List<CompanyRatingModel>> getRatingsForCompany(String companyId) {
    return _firestore
        .collection('companyRatings')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => CompanyRatingModel.fromFirestore(d)).toList();
      list.sort((a, b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      return list;
    });
  }

  Future<CompanyRatingModel?> getMyRatingForCompany({
    required String companyId,
    required String raterUserId,
  }) async {
    final doc = await _firestore
        .collection('companyRatings')
        .doc('${raterUserId}_$companyId')
        .get();
    if (!doc.exists) return null;
    return CompanyRatingModel.fromFirestore(doc);
  }
}