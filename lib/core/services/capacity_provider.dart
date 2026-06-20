import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'capacity_service.dart';
import 'auth_provider.dart';
import '../models/capacity_model.dart';

final capacityServiceProvider =
    Provider<CapacityService>((ref) {
  return CapacityService();
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