import 'dart:async';
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

  /// ONE-OFF admin backfill that re-bands the trust signals already sitting on
  /// existing public posts. New and re-synced posts are banded on write (see
  /// CapacityModel.bandRatingSum), but every post created before that landed
  /// still carries the EXACT rating sum/count and response hours — which is
  /// precisely the tuple an anonymous post could be joined on against the
  /// public companies directory. Until this runs, those old posts stay
  /// de-anonymizable.
  ///
  /// Banding is idempotent (a band of a band is the same band), so this is safe
  /// to re-run and only writes docs whose values actually change.
  ///
  /// Must be run while signed in as an admin — the capacities-update rule
  /// permits admins, so no backend is needed.
  Future<Map<String, int>> rebandPublicPostSignals() async {
    final snap = await _firestore.collection('capacities').get();
    int migrated = 0, skipped = 0, failed = 0;

    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        final sum = (data['posterRatingSum'] as num?)?.toInt() ?? 0;
        final count = (data['posterRatingCount'] as num?)?.toInt() ?? 0;
        final hours = (data['posterAvgResponseHours'] as num?)?.toInt();

        final bandedSum = CapacityModel.bandRatingSum(sum, count);
        final bandedCount = CapacityModel.bandRatingCount(count);
        final bandedHours = CapacityModel.bandResponseHours(hours);

        if (bandedSum == sum &&
            bandedCount == count &&
            bandedHours == hours) {
          skipped++;
          continue;
        }

        await doc.reference.update({
          'posterRatingSum': bandedSum,
          'posterRatingCount': bandedCount,
          if (bandedHours != null) 'posterAvgResponseHours': bandedHours,
        });
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
  /// no longer assigns dealNumber here — that's drawn server-side by the
  /// assignDealNumber Cloud Function trigger the moment status lands on
  /// 'closed' (Admin SDK transaction against counters/deals), since a
  /// client-writable counter let any signed-in account bump/corrupt the
  /// shared sequence directly (see firestore.rules H2 fix). The trigger
  /// keeps a deal's original number if it's later reopened and re-closed.
  Future<void> updateStatus(
    String capacityId,
    CapacityStatus newStatus,
  ) async {
    final Map<String, dynamic> updates = {
      'status': CapacityModel.statusToString(newStatus),
    };
    if (newStatus == CapacityStatus.cancelled) {
      updates['cancelledAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == CapacityStatus.closed) {
      updates['closedAt'] = FieldValue.serverTimestamp();
    }
    await _firestore.collection('capacities').doc(capacityId).update(updates);
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
        if (c.posterSuspended) return false;
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
  /// matching public docs are watched live and shown to the owner.
  ///
  /// This used to do a one-time get() on each capacities/{id} doc instead of
  /// listening to it — so the outer stream only re-fired when a post was
  /// created/removed (capacityOwners changing), never when an EXISTING
  /// post's own status field changed. Result: awarding/negotiating/
  /// cancelling a post updated Firestore correctly, but My Listings kept
  /// showing it under its stale old status until something else happened to
  /// touch capacityOwners. Now each capacities doc is watched live too
  /// (chunked at Firestore's whereIn limit of 30), so a status change shows
  /// up immediately.
  Stream<List<CapacityModel>> getMyCapacities(
    String companyId,
  ) {
    late final StreamController<List<CapacityModel>> controller;
    StreamSubscription? ownerSub;
    List<StreamSubscription> capSubs = [];
    Map<int, Map<String, CapacityModel>> chunkResults = {};

    void emit() {
      final merged = <String, CapacityModel>{};
      for (final chunk in chunkResults.values) {
        merged.addAll(chunk);
      }
      final posts = merged.values.toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
      controller.add(posts);
    }

    void subscribe() {
      ownerSub = _firestore
          .collection('capacityOwners')
          .where('posterCompanyId', isEqualTo: companyId)
          .snapshots()
          .listen((ownerSnap) {
        for (final s in capSubs) {
          s.cancel();
        }
        capSubs = [];
        chunkResults = {};

        final ids = ownerSnap.docs.map((d) => d.id).toList();
        if (ids.isEmpty) {
          controller.add(<CapacityModel>[]);
          return;
        }

        const chunkSize = 30; // Firestore's whereIn cap.
        for (var i = 0; i < ids.length; i += chunkSize) {
          final chunkIndex = i ~/ chunkSize;
          final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
          final chunk = ids.sublist(i, end);
          capSubs.add(_firestore
              .collection('capacities')
              .where(FieldPath.documentId, whereIn: chunk)
              .snapshots()
              .listen((capSnap) {
            chunkResults[chunkIndex] = {
              for (final d in capSnap.docs) d.id: CapacityModel.fromFirestore(d),
            };
            emit();
          }));
        }
      });
    }

    controller = StreamController<List<CapacityModel>>.broadcast(
      onListen: subscribe,
      onCancel: () {
        ownerSub?.cancel();
        for (final s in capSubs) {
          s.cancel();
        }
      },
    );
    return controller.stream;
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
        // Trust signals on the paired public post — banded, never exact, or
        // this sync would re-plant the de-anonymizing join key on every one of
        // the company's posts each time they saved their profile (see
        // CapacityModel.bandRatingSum).
        batch.update(
          _firestore.collection('capacities').doc(doc.id),
          {
            'posterVerified': verified,
            'posterRatingSum':
                CapacityModel.bandRatingSum(ratingSum, ratingCount),
            'posterRatingCount': CapacityModel.bandRatingCount(ratingCount),
          },
        );
      }
      await batch.commit();
    } catch (_) {}
  }
}