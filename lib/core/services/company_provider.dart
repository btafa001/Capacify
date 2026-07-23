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
// and the detail header. PUBLIC fields only: contact lives in the gated
// sidecar, so a model from this stream always has empty email/phone/address.
final companyByIdProvider =
    StreamProvider.family<CompanyModel?, String>((ref, companyId) {
  final service = ref.watch(companyServiceProvider);
  return service.getCompanyStream(companyId);
});

/// A company's gated contact block, or null when the viewer isn't entitled to
/// it (signed out, or signed in without a verified email — see the
/// companyContacts rules). Deliberately a separate, on-demand lookup rather
/// than part of companyByIdProvider: that stream backs every inline rating
/// badge in the feed, and joining contact onto it would fire a contact read
/// per card for data almost none of them display.
final companyContactProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, companyId) {
  final service = ref.watch(companyServiceProvider);
  return service.getCompanyContact(companyId);
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

typedef CollaboratorLookupKey = ({String myCompanyId, String otherCompanyId});

/// Null unless a granted contact_request actually connects the two companies —
/// gates the "Bewerten" button on a real collaboration (see
/// CompanyService.findGrantedRequestId).
final grantedRequestIdProvider =
    FutureProvider.family<String?, CollaboratorLookupKey>((ref, key) async {
  final service = ref.watch(companyServiceProvider);
  return service.findGrantedRequestId(
    myCompanyId: key.myCompanyId,
    otherCompanyId: key.otherCompanyId,
  );
});

/// How many companies this one referred (see CompanyService.countReferrals) —
/// shown in Settings.
final referralCountProvider =
    FutureProvider.family<int, String>((ref, companyId) async {
  final service = ref.watch(companyServiceProvider);
  return service.countReferrals(companyId);
});