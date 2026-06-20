import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/capacity_model.dart';

class CapacityService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ─── CRUD ───

  Future<void> createCapacity(
    CapacityModel capacity,
  ) async {
    await _firestore
        .collection('capacities')
        .add(capacity.toFirestore());
  }

  Future<void> updateCapacity(
    CapacityModel capacity,
  ) async {
    await _firestore
        .collection('capacities')
        .doc(capacity.id)
        .update(capacity.toFirestoreForUpdate());
  }

  // ─── LIFECYCLE — never hard delete ───

  /// Update status with timestamps for closed/cancelled. Closing a deal
  /// for the first time also assigns it a sequential dealNumber, drawn
  /// atomically from counters/deals so concurrent closures can't collide.
  /// If a deal is later reopened and re-closed, it keeps its original
  /// number rather than being issued a new one.
  Future<void> updateStatus(
    String capacityId,
    CapacityStatus newStatus,
  ) async {
    if (newStatus != CapacityStatus.closed) {
      final Map<String, dynamic> updates = {
        'status': CapacityModel.statusToString(newStatus),
      };
      if (newStatus == CapacityStatus.cancelled) {
        updates['cancelledAt'] = FieldValue.serverTimestamp();
      }
      await _firestore
          .collection('capacities')
          .doc(capacityId)
          .update(updates);
      return;
    }

    final capacityRef = _firestore.collection('capacities').doc(capacityId);
    final counterRef = _firestore.collection('counters').doc('deals');

    await _firestore.runTransaction((tx) async {
      final capacitySnap = await tx.get(capacityRef);
      final existingNumber = capacitySnap.data()?['dealNumber'] as int?;

      final updates = <String, dynamic>{
        'status': CapacityModel.statusToString(CapacityStatus.closed),
        'closedAt': FieldValue.serverTimestamp(),
      };

      if (existingNumber == null) {
        final counterSnap = await tx.get(counterRef);
        final nextNumber = ((counterSnap.data()?['value'] ?? 0) as int) + 1;
        tx.set(counterRef, {'value': nextNumber});
        updates['dealNumber'] = nextNumber;
      }

      tx.update(capacityRef, updates);
    });
  }

  // ─── ENGAGEMENT ───

  Future<void> incrementViewCount(
    String capacityId,
  ) async {
    try {
      await _firestore
          .collection('capacities')
          .doc(capacityId)
          .update({'viewCount': FieldValue.increment(1)});
    } catch (_) {}
  }

  Future<void> incrementInterestCount(
    String capacityId,
  ) async {
    try {
      await _firestore
          .collection('capacities')
          .doc(capacityId)
          .update(
            {'interestCount': FieldValue.increment(1)},
          );
    } catch (_) {}
  }

  Future<bool> toggleFavorite({
    required String capacityId,
    required String userId,
  }) async {
    try {
      final docRef = _firestore
          .collection('userFavorites')
          .doc('${userId}_$capacityId');
      final favDoc = await docRef.get();

      if (favDoc.exists) {
        await docRef.delete();
        await _firestore
            .collection('capacities')
            .doc(capacityId)
            .update(
              {'favoriteCount': FieldValue.increment(-1)},
            );
        return false;
      } else {
        await docRef.set({
          'userId': userId,
          'capacityId': capacityId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('capacities')
            .doc(capacityId)
            .update(
              {'favoriteCount': FieldValue.increment(1)},
            );
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> isFavorited({
    required String capacityId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('userFavorites')
          .doc('${userId}_$capacityId')
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ─── STREAMS ───

  /// Main feed — shows active + inProgress only
  Stream<List<CapacityModel>> getCapacities({
    String? trade,
    CapacityType? type,
  }) {
    return _firestore
        .collection('capacities')
        .where(
          'status',
          whereIn: ['active', 'inProgress'],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final all = snapshot.docs
          .map((doc) => CapacityModel.fromFirestore(doc))
          .toList();

      return all.where((c) {
        if (c.contentFlagged) return false;
        final matchesTrade = trade == null ||
            trade.isEmpty ||
            c.trade == trade;
        final matchesType =
            type == null || c.type == type;
        return matchesTrade && matchesType;
      }).toList();
    });
  }

  /// My postings — returns ALL statuses for history
  Stream<List<CapacityModel>> getMyCapacities(
    String companyId,
  ) {
    return _firestore
        .collection('capacities')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CapacityModel.fromFirestore(doc),
              )
              .toList(),
        );
  }

  // ─── FAVORITES FEED ───

  Stream<Set<String>> getUserFavoriteIds(
    String userId,
  ) {
    return _firestore
        .collection('userFavorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) =>
                    d.data()['capacityId'] as String,
              )
              .toSet(),
        );
  }

  Stream<List<CapacityModel>> getUserFavoriteCapacities(
    String userId,
  ) {
    return _firestore
        .collection('userFavorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((favSnap) async {
      if (favSnap.docs.isEmpty) return [];
      final ids = favSnap.docs
          .map((d) => d.data()['capacityId'] as String)
          .toList();
      final List<CapacityModel> capacities = [];
      for (final id in ids) {
        try {
          final doc = await _firestore
              .collection('capacities')
              .doc(id)
              .get();
          if (doc.exists) {
            capacities
                .add(CapacityModel.fromFirestore(doc));
          }
        } catch (_) {}
      }
      return capacities;
    });
  }

  /// Sync company info to all their posts
  Future<void> updateCompanyNameOnAllPosts({
    required String companyId,
    required String newName,
    required String newCity,
    required String newPhone,
    required String newEmail,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('capacities')
          .where('companyId', isEqualTo: companyId)
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'companyName': newName,
          'companyCity': newCity,
          'companyPhone': newPhone,
          'companyEmail': newEmail,
        });
      }
      await batch.commit();
    } catch (_) {}
  }
}