import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'company_service.dart';
import '../models/company_model.dart';
import '../models/company_rating_model.dart';

final companyServiceProvider = Provider<CompanyService>((ref) {
  return CompanyService();
});

final myCompanyProvider =
    FutureProvider.family<CompanyModel?, String>((ref, ownerId) async {
  final service = ref.watch(companyServiceProvider);
  return service.getCompanyByOwner(ownerId);
});

final companiesProvider = StreamProvider<List<CompanyModel>>((ref) {
  final service = ref.watch(companyServiceProvider);
  return service.getCompanies();
});

// Single company by ID — used for inline rating badges (e.g. on capacity cards)
final companyByIdProvider =
    StreamProvider.family<CompanyModel?, String>((ref, companyId) {
  final service = ref.watch(companyServiceProvider);
  return service.getCompanyStream(companyId);
});

final companyRatingsProvider =
    StreamProvider.family<List<CompanyRatingModel>, String>((ref, companyId) {
  final service = ref.watch(companyServiceProvider);
  return service.getRatingsForCompany(companyId);
});

typedef RatingLookupKey = ({String companyId, String userId});

final myRatingForCompanyProvider =
    FutureProvider.family<CompanyRatingModel?, RatingLookupKey>((ref, key) async {
  final service = ref.watch(companyServiceProvider);
  return service.getMyRatingForCompany(
    companyId: key.companyId,
    raterUserId: key.userId,
  );
});