import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../models/company_rating_model.dart';

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
  // is flagged and awaiting admin review.
  Stream<List<CompanyModel>> getCompanies() {
    return _firestore
        .collection('companies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CompanyModel.fromFirestore(doc))
            .where((c) => !c.contentFlagged)
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
  Future<void> submitRating({
    required String companyId,
    required String raterUserId,
    required String raterCompanyName,
    required int rating,
    required String comment,
  }) async {
    final ratingRef =
        _firestore.collection('companyRatings').doc('${raterUserId}_$companyId');

    final existingSnap = await ratingRef.get();
    final companySnap =
        await _firestore.collection('companies').doc(companyId).get();
    final ratedCompanyName = companySnap.data()?['name'] ?? '';

    await ratingRef.set({
      'raterUserId': raterUserId,
      'raterCompanyName': raterCompanyName,
      'companyId': companyId,
      'ratedCompanyName': ratedCompanyName,
      'rating': rating,
      'comment': comment,
      'status': 'pending',
      'createdAt': existingSnap.exists
          ? (existingSnap.data()?['createdAt'])
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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