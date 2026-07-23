import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_service.dart';
import 'auth_provider.dart';
import 'report_provider.dart';
import '../utils/listener_diagnostics.dart';
import '../models/company_model.dart';
import '../models/company_rating_model.dart';
import '../models/capacity_model.dart';
import '../models/report_model.dart';

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

// Every query below is admin-only in firestore.rules: the ONLY branch that can
// pass is isAdmin(). These used to fire on `ref.read` the instant the admin
// screen mounted, and the dashboard watches several of them for badge counts on
// EVERY account — so each ordinary, non-admin session opened admin-only
// listeners that the rules can only ever deny. That is one guaranteed
// permission-denied per non-admin session (it showed up in production as
// `[listener-denied] pendingRatings authed=true sinceStart=0s`), a listener that
// can never deliver anything, and a skewed denied-request metric.
//
// The gate is CONFIRMED ADMIN, not merely signed in. isAdminProvider resolves
// from the user's own users/{uid} doc, which is the same fact firestore.rules
// checks, so the query now goes out only when it can actually pass. Non-admin
// and signed-out alike return an empty stream rather than an error: for a badge
// count those are normal states, not failures — and an error here would latch
// (a denied Firestore listener terminates and Riverpod caches the AsyncError,
// which is why these screens used to stay broken until a full page reload).

/// True once the user's own doc has confirmed admin — the gate every admin-only
/// listener below waits on before it touches Firestore.
bool _isAdmin(Ref ref) =>
    ref.watch(isAdminProvider).valueOrNull ?? false;

final pendingCompaniesProvider = StreamProvider<List<CompanyModel>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref
      .read(adminServiceProvider)
      .getPendingCompanies()
      .logPermissionDenials('pendingCompanies');
});

final allCompaniesAdminProvider = StreamProvider<List<CompanyModel>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref
      .read(adminServiceProvider)
      .getAllCompanies()
      .logPermissionDenials('allCompaniesAdmin');
});

final pendingRatingsProvider = StreamProvider<List<CompanyRatingModel>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref
      .read(adminServiceProvider)
      .getPendingRatings()
      .logPermissionDenials('pendingRatings');
});

final flaggedCapacitiesProvider = StreamProvider<List<CapacityModel>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref
      .read(adminServiceProvider)
      .getFlaggedCapacities()
      .logPermissionDenials('flaggedCapacities');
});

final flaggedCompaniesProvider = StreamProvider<List<CompanyModel>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref
      .read(adminServiceProvider)
      .getFlaggedCompanies()
      .logPermissionDenials('flaggedCompanies');
});

// User-filed reports (report_service.dart) — distinct from the content-
// moderation flags above (auto/system-detected). Previously had no admin UI
// at all: getAllReports() existed but nothing ever called it, so reports sat
// unseen. allReportsProvider feeds the full history list; pendingReportsProvider
// drives the tab badge count.
final allReportsProvider = StreamProvider<List<ReportModel>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref
      .read(reportServiceProvider)
      .getAllReports()
      .logPermissionDenials('allReports');
});

final pendingReportsProvider = Provider<List<ReportModel>>((ref) {
  final all = ref.watch(allReportsProvider).valueOrNull ?? [];
  return all.where((r) => r.status == 'pending').toList();
});

/// postId → posterCompanyId for every post (admin-only read of the locked
/// owner sidecars). Powers the per-company posting metrics on the admin
/// Dashboard (posts-per-company, "no listing", onboarding funnel, reactivation).
final capacityOwnerMapProvider = StreamProvider<Map<String, String>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const {});
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
  }).logPermissionDenials('capacityOwnerMap');
});
