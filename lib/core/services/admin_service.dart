import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../models/company_rating_model.dart';
import '../models/capacity_model.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;

  Stream<List<CompanyModel>> getPendingCompanies() {
    return _db
        .collection('companies')
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map(CompanyModel.fromFirestore).toList());
  }

  Stream<List<CompanyModel>> getAllCompanies() {
    return _db
        .collection('companies')
        .snapshots()
        .map((s) {
      final list = s.docs.map(CompanyModel.fromFirestore).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Future<void> approveVerification(String companyId) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .update({'verificationStatus': 'verified'});

    // Batch-update all existing capacity docs for this company
    final caps = await _db
        .collection('capacities')
        .where('companyId', isEqualTo: companyId)
        .get();
    if (caps.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in caps.docs) {
        batch.update(doc.reference, {'companyVerified': true});
      }
      await batch.commit();
    }
  }

  Future<void> rejectVerification(String companyId) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .update({'verificationStatus': 'rejected'});
  }

  Future<void> revokeVerification(String companyId) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .update({'verificationStatus': 'none'});
    final caps = await _db
        .collection('capacities')
        .where('companyId', isEqualTo: companyId)
        .get();
    if (caps.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in caps.docs) {
        batch.update(doc.reference, {'companyVerified': false});
      }
      await batch.commit();
    }
  }

  // ─── RATING MODERATION ───

  Stream<List<CompanyRatingModel>> getPendingRatings() {
    return _db
        .collection('companyRatings')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
      final list = s.docs.map(CompanyRatingModel.fromFirestore).toList();
      list.sort((a, b) => (b.updatedAt ?? DateTime(0))
          .compareTo(a.updatedAt ?? DateTime(0)));
      return list;
    });
  }

  /// Approving makes the rating publicly visible and adds it to the
  /// company's ratingSum/ratingCount average. Re-reads the rating doc
  /// inside the transaction so a double-tap can't double-count it.
  Future<void> approveRating(String ratingId) async {
    final ratingRef = _db.collection('companyRatings').doc(ratingId);
    await _db.runTransaction((tx) async {
      final ratingSnap = await tx.get(ratingRef);
      if (!ratingSnap.exists) return;
      final data = ratingSnap.data()!;
      if (data['status'] == 'approved') return;

      final companyId = data['companyId'] as String;
      final ratingValue = (data['rating'] ?? 0) as int;
      final companyRef = _db.collection('companies').doc(companyId);
      final companySnap = await tx.get(companyRef);
      final currentSum = (companySnap.data()?['ratingSum'] ?? 0) as int;
      final currentCount = (companySnap.data()?['ratingCount'] ?? 0) as int;

      tx.update(ratingRef, {'status': 'approved'});
      tx.update(companyRef, {
        'ratingSum': currentSum + ratingValue,
        'ratingCount': currentCount + 1,
      });
    });
  }

  /// Rejecting just hides it — a pending rating was never counted, so
  /// there's no aggregate to undo.
  Future<void> rejectRating(String ratingId) async {
    await _db
        .collection('companyRatings')
        .doc(ratingId)
        .update({'status': 'rejected'});
  }

  // ─── FLAGGED CONTENT MODERATION ───
  //
  // Posts/profiles whose free text matched the blocklist are hidden from
  // public view (see CapacityService.getCapacities / CompanyService
  // .getCompanies) until cleared here. There's no separate "reject" —
  // leaving something flagged already keeps it hidden indefinitely; the
  // owner can edit and resubmit, which re-runs the check.

  Stream<List<CapacityModel>> getFlaggedCapacities() {
    return _db
        .collection('capacities')
        .where('contentFlagged', isEqualTo: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map(CapacityModel.fromFirestore).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Stream<List<CompanyModel>> getFlaggedCompanies() {
    return _db
        .collection('companies')
        .where('contentFlagged', isEqualTo: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map(CompanyModel.fromFirestore).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  Future<void> approveFlaggedCapacity(String capacityId) async {
    await _db
        .collection('capacities')
        .doc(capacityId)
        .update({'contentFlagged': false});
  }

  Future<void> approveFlaggedCompany(String companyId) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .update({'contentFlagged': false});
  }
}
