import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_service.dart';
import 'auth_provider.dart';
import '../models/company_model.dart';
import '../models/company_rating_model.dart';
import '../models/capacity_model.dart';

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  return doc.data()?['isAdmin'] as bool? ?? false;
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
