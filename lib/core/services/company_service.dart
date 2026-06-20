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
      query = query.where('trade', isEqualTo: trade);
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

  /// Creates or updates the rater's rating for a company. Never counts
  /// toward the company's average directly — every submission goes to
  /// 'pending' and only counts once an admin approves it (see AdminService).
  /// If the rater is editing a rating that was already approved, its old
  /// value is removed from the aggregate now, since the edited content
  /// needs fresh review before it can count again.
  Future<void> submitRating({
    required String companyId,
    required String raterUserId,
    required String raterCompanyName,
    required int rating,
    required String comment,
  }) async {
    final ratingRef =
        _firestore.collection('companyRatings').doc('${raterUserId}_$companyId');
    final companyRef = _firestore.collection('companies').doc(companyId);

    await _firestore.runTransaction((tx) async {
      final existingSnap = await tx.get(ratingRef);
      final companySnap = await tx.get(companyRef);
      final companyData = companySnap.data() ?? {};
      final ratedCompanyName = companyData['name'] ?? '';

      if (existingSnap.exists && existingSnap.data()?['status'] == 'approved') {
        final oldRating = (existingSnap.data()?['rating'] ?? 0) as int;
        final currentSum = (companyData['ratingSum'] ?? 0) as int;
        final currentCount = (companyData['ratingCount'] ?? 0) as int;
        tx.update(companyRef, {
          'ratingSum': currentSum - oldRating,
          'ratingCount': currentCount - 1,
        });
      }

      tx.set(ratingRef, {
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
    });
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