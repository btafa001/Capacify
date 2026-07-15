import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'capacity_service.dart';
import 'auth_provider.dart';
import '../models/capacity_model.dart';

final capacityServiceProvider =
    Provider<CapacityService>((ref) {
  return CapacityService();
});

/// Real "proof of life" counts for the landing page — companies on the
/// platform + currently-active capacities. Uses count() aggregates (one billed
/// read each, no doc downloads) and both collections are public-read, so it
/// works for signed-out visitors. Never fabricated — returns zeros on failure.
final marketPulseProvider =
    FutureProvider<({int companies, int activeCapacities})>((ref) async {
  final fs = FirebaseFirestore.instance;
  try {
    final comp = await fs.collection('companies').count().get();
    final caps = await fs
        .collection('capacities')
        .where('status', whereIn: ['active', 'inProgress'])
        .count()
        .get();
    return (companies: comp.count ?? 0, activeCapacities: caps.count ?? 0);
  } catch (_) {
    return (companies: 0, activeCapacities: 0);
  }
});

final capacitiesProvider =
    StreamProvider<List<CapacityModel>>((ref) {
  final service = ref.watch(capacityServiceProvider);
  return service.getCapacities();
});

final myCapacitiesProvider =
    StreamProvider.family<List<CapacityModel>, String>(
        (ref, companyId) {
  final service = ref.watch(capacityServiceProvider);
  return service.getMyCapacities(companyId);
});

// One-time lookup by id — used by chat_screen.dart to decide whether the
// underlying post is closed/cancelled yet (only then can its chat be deleted).
final capacityByIdProvider =
    FutureProvider.family<CapacityModel?, String>((ref, id) {
  final service = ref.watch(capacityServiceProvider);
  return service.getCapacityById(id);
});

// Stream of capacity IDs this user has favorited
final userFavoriteIdsProvider =
    StreamProvider<Set<String>>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return Stream.value({});
  final service = ref.watch(capacityServiceProvider);
  return service.getUserFavoriteIds(authState.uid);
});

// Stream of actual favorited capacities
final userFavoriteCapacitiesProvider =
    StreamProvider<List<CapacityModel>>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return Stream.value([]);
  final service = ref.watch(capacityServiceProvider);
  return service
      .getUserFavoriteCapacities(authState.uid);
});