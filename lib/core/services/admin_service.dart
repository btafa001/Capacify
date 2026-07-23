import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../models/company_rating_model.dart';
import '../models/capacity_model.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;

  /// Every company's gated contact block, keyed by company id.
  ///
  /// Contact data no longer lives on the public company doc (see
  /// CompanyModel's class doc), so the admin console — which legitimately
  /// shows and USES it, e.g. sending the set-password invite to
  /// company.email — has to join it back on. Listing this collection is
  /// admin-only in firestore.rules, which is exactly what stops a
  /// merely-verified user from bulk-reading it. Fails closed: a denied or
  /// failed read yields an empty map, so the console degrades to blank
  /// contact rather than breaking outright.
  Future<Map<String, Map<String, dynamic>>> _contactsById() async {
    try {
      final snap = await _db.collection('companyContacts').get();
      return {for (final d in snap.docs) d.id: d.data()};
    } catch (_) {
      return const {};
    }
  }

  Stream<List<CompanyModel>> getPendingCompanies() {
    return _db
        .collection('companies')
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((s) async {
      final contacts = await _contactsById();
      return s.docs
          .map((d) => CompanyModel.fromFirestore(d).withContact(contacts[d.id]))
          .toList();
    });
  }

  Stream<List<CompanyModel>> getAllCompanies() {
    return _db
        .collection('companies')
        .snapshots()
        .asyncMap((s) async {
      final contacts = await _contactsById();
      final list = s.docs
          .map((d) => CompanyModel.fromFirestore(d).withContact(contacts[d.id]))
          .toList();
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

  // ─── SUSPENSION (moderation consequence) ───
  //
  // Distinct from contentFlagged (auto-detected bad text): this is a
  // deliberate admin action for behavioral violations. While suspended a
  // company can't publish new posts (enforced in firestore.rules' capacities
  // create rule) and its EXISTING posts disappear from the public feed —
  // via the posterSuspended snapshot on each post, since anonymous-mode
  // posts carry no companyId to filter by directly (see capacityOwners,
  // the only place poster identity lives). Looked up through that sidecar
  // rather than the legacy `companyId` field on capacities, which predates
  // the anonymization split and is empty on every current post.
  Future<void> _setPostsSuspended(String companyId, bool suspended) async {
    final owners = await _db
        .collection('capacityOwners')
        .where('posterCompanyId', isEqualTo: companyId)
        .get();
    if (owners.docs.isEmpty) return;
    final batch = _db.batch();
    for (final owner in owners.docs) {
      batch.update(
        _db.collection('capacities').doc(owner.id),
        {'posterSuspended': suspended},
      );
    }
    await batch.commit();
  }

  Future<void> suspendCompany(String companyId, String reason) async {
    await _db.collection('companies').doc(companyId).update({
      'suspended': true,
      'suspensionReason': reason,
    });
    await _setPostsSuspended(companyId, true);
  }

  Future<void> unsuspendCompany(String companyId) async {
    await _db.collection('companies').doc(companyId).update({
      'suspended': false,
      'suspensionReason': '',
    });
    await _setPostsSuspended(companyId, false);
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

  /// The denormalized ratingSum/ratingCount on a company doc is ADMIN-ONLY
  /// (firestore.rules blocks every non-admin from writing it, so it can't be
  /// forged). It is the exact sum/count of that company's *approved* reviews,
  /// recomputed from scratch here on every moderation action. Recomputing
  /// (rather than incrementing) means the number is always self-consistent and
  /// self-healing — a client that edits/withdraws an approved rating can't
  /// leave it permanently wrong, and a double-tap can't double-count.
  Future<void> _recomputeRatingAggregate(String companyId) async {
    final approved = await _db
        .collection('companyRatings')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'approved')
        .get();
    int sum = 0;
    for (final d in approved.docs) {
      sum += (d.data()['rating'] ?? 0) as int;
    }
    await _db.collection('companies').doc(companyId).update({
      'ratingSum': sum,
      'ratingCount': approved.docs.length,
    });
  }

  /// Approving makes the rating publicly visible, then recomputes the
  /// company's aggregate from all approved reviews.
  Future<void> approveRating(String ratingId) async {
    final ratingRef = _db.collection('companyRatings').doc(ratingId);
    final snap = await ratingRef.get();
    if (!snap.exists) return;
    final companyId = snap.data()!['companyId'] as String;
    await ratingRef.update({'status': 'approved'});
    await _recomputeRatingAggregate(companyId);
  }

  /// Rejecting hides the review. Recompute afterwards in case the rating was
  /// previously approved (so its contribution is removed from the aggregate).
  Future<void> rejectRating(String ratingId) async {
    final ratingRef = _db.collection('companyRatings').doc(ratingId);
    final snap = await ratingRef.get();
    if (!snap.exists) return;
    final companyId = snap.data()!['companyId'] as String;
    await ratingRef.update({'status': 'rejected'});
    await _recomputeRatingAggregate(companyId);
  }

  /// Admin hard-delete of a review, followed by an aggregate recompute so the
  /// denormalized score updates immediately (unlike a rater self-withdrawal,
  /// which can't write the aggregate and self-heals on the next moderation).
  Future<void> deleteRatingAndRecompute({
    required String ratingId,
    required String companyId,
  }) async {
    await _db.collection('companyRatings').doc(ratingId).delete();
    await _recomputeRatingAggregate(companyId);
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
        .asyncMap((s) async {
      final contacts = await _contactsById();
      final list = s.docs
          .map((d) => CompanyModel.fromFirestore(d).withContact(contacts[d.id]))
          .toList();
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
