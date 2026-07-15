import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_service.dart';
import 'auth_provider.dart';
import '../models/company_model.dart';
import '../models/company_rating_model.dart';
import '../models/capacity_model.dart';

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

// A live listener, not a one-time get(): isAdmin can be granted while the
// user is already signed in, and a one-shot read would only pick that up
// on the next sign-in (only authStateProvider changing re-triggers it).
final isAdminProvider = StreamProvider.autoDispose<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['isAdmin'] as bool? ?? false);
});

final pendingCompaniesProvider = StreamProvider<List<CompanyModel>>((ref) {
  return ref.read(adminServiceProvider).getPendingCompanies();
});

final allCompaniesAdminProvider = StreamProvider<List<CompanyModel>>((ref) {
  return ref.read(adminServiceProvider).getAllCompanies();
});

final pendingRatingsProvider = StreamProvider<List<CompanyRatingModel>>((ref) {
  return ref.read(adminServiceProvider).getPendingRatings();
});

final flaggedCapacitiesProvider = StreamProvider<List<CapacityModel>>((ref) {
  return ref.read(adminServiceProvider).getFlaggedCapacities();
});

final flaggedCompaniesProvider = StreamProvider<List<CompanyModel>>((ref) {
  return ref.read(adminServiceProvider).getFlaggedCompanies();
});

/// postId → posterCompanyId for every post (admin-only read of the locked
/// owner sidecars). Powers the per-company posting metrics on the admin
/// Dashboard (posts-per-company, "no listing", onboarding funnel, reactivation).
final capacityOwnerMapProvider = StreamProvider<Map<String, String>>((ref) {
  return FirebaseFirestore.instance
      .collection('capacityOwners')
      .snapshots()
      .map((s) {
    final map = <String, String>{};
    for (final d in s.docs) {
      final pid = d.data()['posterCompanyId'] as String?;
      if (pid != null && pid.isNotEmpty) map[d.id] = pid;
    }
    return map;
  });
});
