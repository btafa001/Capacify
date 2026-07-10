import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/capacity_model.dart';
import '../models/capacity_owner_model.dart';

class CapacityService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // UTC 'YYYY-MM-DD' — matches the server request.time used by the throttle rule.
  String _todayStr() {
    final n = DateTime.now().toUtc();
    final mm = n.month.toString().padLeft(2, '0');
    final dd = n.day.toString().padLeft(2, '0');
    return '${n.year}-$mm-$dd';
  }

  // ─── CRUD ───

  /// Creates a post as TWO documents in one batch: the public, anonymized
  /// capacities/{id} and the locked capacityOwners/{id} identity sidecar.
  /// The same auto-id ties them together; nothing on the public doc reveals
  /// the poster.
  ///
  /// The batch also bumps the poster's daily post counter (postCounts/{uid}).
  /// Its rule caps the count at [kMaxPostsPerDay]; once exceeded the counter
  /// write is denied and — batches being atomic — the whole post is rejected.
  /// That's the anti-spam throttle, enforced server-side without touching the
  /// post/owner create rules.
  Future<void> createCapacity(
    CapacityModel capacity, {
    required CapacityOwnerModel owner,
  }) async {
    final uid = owner.posterCompanyId;
    final today = _todayStr();
    final countRef = _firestore.collection('postCounts').doc(uid);
    final countSnap = await countRef.get();
    final sameDay = countSnap.exists && countSnap.data()?['day'] == today;
    final newCount = sameDay ? ((countSnap.data()?['count'] ?? 0) as int) + 1 : 1;

    final ref = _firestore.collection('capacities').doc();
    final batch = _firestore.batch();
    batch.set(ref, capacity.toFirestore());
    batch.set(
      _firestore.collection('capacityOwners').doc(ref.id),
      owner.toFirestore(),
    );
    batch.set(countRef, {'day': today, 'count': newCount});
    await batch.commit();
  }

  /// How many posts a company has published (counted on the locked sidecar,
  /// which is the queryable owner index). Used by the admin request queue as a
  /// lightweight "repeat poster" signal — a server-side count aggregate, so
  /// it's a single billed read regardless of how many posts match.
  Future<int> countOwnerPosts(String companyId) async {
    try {
      final agg = await _firestore
          .collection('capacityOwners')
          .where('posterCompanyId', isEqualTo: companyId)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// ONE-OFF admin migration for legacy posts created before the anonymization
  /// split. Each legacy `capacities/{id}` still embeds identity
  /// (companyName/Phone/Email/Id/City/Verified) in its PUBLIC doc — a live leak.
  /// For every such doc this: (1) creates the locked `capacityOwners/{id}`
  /// sidecar from the embedded identity, (2) strips the identity fields off the
  /// public doc, (3) backfills the non-identifying trust signals
  /// (posterVerified/RatingSum/RatingCount) from the company doc, and (4)
  /// normalizes legacy trade values to the consolidated set. Idempotent — a doc
  /// with no `companyName` is already migrated and skipped, so re-running is safe.
  ///
  /// Must be run while signed in as an admin: the capacities-update and
  /// capacityOwners-create rules both permit admins, so no backend is needed.
  Future<Map<String, int>> migrateLegacyIdentityPosts() async {
    const tradeMerge = {
      'Stahl': 'Beton & Stahl',
      'Beton': 'Beton & Stahl',
      'HVAC': 'SHK',
      'Sanitär & Heizung': 'SHK',
      'Fliesenleger': 'Fliesen & Boden',
      'Bodenleger': 'Fliesen & Boden',
    };
    final snap = await _firestore.collection('capacities').get();
    final companyCache = <String, Map<String, dynamic>?>{};
    int migrated = 0, skipped = 0, failed = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      // Already clean (no embedded identity) → nothing to do.
      if (data['companyName'] == null) {
        skipped++;
        continue;
      }
      final companyId = (data['companyId'] as String?) ?? '';
      if (companyId.isEmpty) {
        skipped++;
        continue;
      }
      try {
        Map<String, dynamic>? company;
        if (companyCache.containsKey(companyId)) {
          company = companyCache[companyId];
        } else {
          final cdoc =
              await _firestore.collection('companies').doc(companyId).get();
          company = cdoc.exists ? cdoc.data() : null;
          companyCache[companyId] = company;
        }
        final verified = company != null
            ? company['verificationStatus'] == 'verified'
            : data['companyVerified'] == true;
        final ratingSum = (company?['ratingSum'] as int?) ?? 0;
        final ratingCount = (company?['ratingCount'] as int?) ?? 0;

        final batch = _firestore.batch();
        // 1) Locked identity sidecar.
        batch.set(_firestore.collection('capacityOwners').doc(doc.id), {
          'posterCompanyId': companyId,
          'companyName': data['companyName'],
          'contactPhone': data['companyPhone'] ?? '',
          'contactEmail': data['companyEmail'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        // 2) Strip identity from the public doc + add trust signals.
        final updates = <String, dynamic>{
          'companyName': FieldValue.delete(),
          'companyPhone': FieldValue.delete(),
          'companyEmail': FieldValue.delete(),
          'companyId': FieldValue.delete(),
          'companyCity': FieldValue.delete(),
          'companyVerified': FieldValue.delete(),
          'posterVerified': verified,
          'posterRatingSum': ratingSum,
          'posterRatingCount': ratingCount,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // 3) Normalize any legacy trade value to the consolidated set.
        final trade = data['trade'];
        if (trade is String && tradeMerge.containsKey(trade)) {
          updates['trade'] = tradeMerge[trade];
        }
        batch.update(doc.reference, updates);
        await batch.commit();
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  /// Reads the locked identity sidecar. Firestore rules return it only to the
  /// owner, an admin, or a requester with a granted contact request — so a
  /// permission-denied here means "not granted" and surfaces as null.
  Future<CapacityOwnerModel?> getCapacityOwner(String postId) async {
    try {
      final doc = await _firestore.collection('capacityOwners').doc(postId).get();
      if (!doc.exists) return null;
      return CapacityOwnerModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  /// One-tap "still free" — the poster re-confirms availability and extends the
  /// window a fresh [extendDays] from today. Keeps supply live (drives the
  /// "heute bestätigt" freshness signal + feeds CapacityOS) and is a return
  /// trigger for the supply side. Owner-only via the capacities update rule.
  Future<void> reconfirmAvailability({
    required String capacityId,
    int extendDays = 7,
  }) async {
    final updates = <String, dynamic>{
      'availabilityConfirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (extendDays > 0) {
      updates['availableTo'] =
          Timestamp.fromDate(DateTime.now().add(Duration(days: extendDays)));
    }
    await _firestore.collection('capacities').doc(capacityId).update(updates);
  }

  Future<void> updateCapacity(
    CapacityModel capacity,
  ) async {
    await _firestore
        .collection('capacities')
        .doc(capacity.id)
        .update(capacity.toFirestoreForUpdate());
  }

  // Used to resolve a shared post link (e.g. ?capacity=<id>) back to a
  // capacity — returns null if the id doesn't exist rather than throwing,
  // since a stale/invalid shared link shouldn't crash the app on load.
  Future<CapacityModel?> getCapacityById(String id) async {
    final doc = await _firestore.collection('capacities').doc(id).get();
    if (!doc.exists) return null;
    return CapacityModel.fromFirestore(doc);
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

  /// Main feed — shows active + inProgress only.
  ///
  /// Bounded to the newest [limit] docs: an unbounded realtime stream of the
  /// whole collection would bill a read per doc per visitor and grow client
  /// memory without limit as supply scales — a launch-time footgun. Expired
  /// posts (availability window already ended) are filtered out so a stale
  /// "team available last week" doesn't make a live market look dead.
  Stream<List<CapacityModel>> getCapacities({
    String? trade,
    CapacityType? type,
    int limit = 60,
  }) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('capacities')
        .where(
          'status',
          whereIn: ['active', 'inProgress'],
        )
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final all = snapshot.docs
          .map((doc) => CapacityModel.fromFirestore(doc))
          .toList();

      return all.where((c) {
        if (c.contentFlagged) return false;
        if (c.availableTo.isBefore(startOfToday)) return false;
        final matchesTrade = trade == null ||
            trade.isEmpty ||
            c.trade == trade;
        final matchesType =
            type == null || c.type == type;
        return matchesTrade && matchesType;
      }).toList();
    });
  }

  /// My postings — returns ALL statuses for history. The public posts no
  /// longer carry companyId, so ownership is resolved through the locked
  /// capacityOwners sidecar (queryable by the owner via rules), then the
  /// matching public docs are fetched and shown to the owner.
  Stream<List<CapacityModel>> getMyCapacities(
    String companyId,
  ) {
    return _firestore
        .collection('capacityOwners')
        .where('posterCompanyId', isEqualTo: companyId)
        .snapshots()
        .asyncMap((ownerSnap) async {
      final ids = ownerSnap.docs.map((d) => d.id).toList();
      if (ids.isEmpty) return <CapacityModel>[];
      final List<CapacityModel> posts = [];
      for (final id in ids) {
        try {
          final doc =
              await _firestore.collection('capacities').doc(id).get();
          if (doc.exists) posts.add(CapacityModel.fromFirestore(doc));
        } catch (_) {}
      }
      posts.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return posts;
    });
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

  /// Sync the company's contact snapshot onto all their posts. Identity now
  /// lives on the locked capacityOwners sidecars (not the public posts), so
  /// this updates those — keeping each post's grant-released contact current
  /// when the company edits its profile.
  Future<void> updateCompanyNameOnAllPosts({
    required String companyId,
    required String newName,
    required String newCity,
    required String newPhone,
    required String newEmail,
    bool verified = false,
    int ratingSum = 0,
    int ratingCount = 0,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('capacityOwners')
          .where('posterCompanyId', isEqualTo: companyId)
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        // Identity/contact snapshot on the locked sidecar.
        batch.update(doc.reference, {
          'companyName': newName,
          'contactPhone': newPhone,
          'contactEmail': newEmail,
        });
        // Non-identifying trust signals on the paired public post.
        batch.update(
          _firestore.collection('capacities').doc(doc.id),
          {
            'posterVerified': verified,
            'posterRatingSum': ratingSum,
            'posterRatingCount': ratingCount,
          },
        );
      }
      await batch.commit();
    } catch (_) {}
  }
}