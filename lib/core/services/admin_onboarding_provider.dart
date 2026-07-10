import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_onboarding_service.dart';
import 'admin_provider.dart';
import '../models/company_model.dart';

final adminOnboardingServiceProvider =
    Provider<AdminOnboardingService>((ref) => AdminOnboardingService());

/// Admin-created companies that haven't been sent their invite yet — the
/// "finish the flow / send the invite" follow-up list. Derived from the
/// existing allCompaniesAdminProvider stream so it stays live with no extra
/// query.
final adminCreatedNotInvitedProvider =
    Provider<List<CompanyModel>>((ref) {
  final all = ref.watch(allCompaniesAdminProvider).valueOrNull ?? [];
  return all
      .where((c) => c.onboardingSource == 'admin' && c.invitedAt == null)
      .toList();
});

/// Admin-created companies that HAVE been invited — "invited, waiting on them
/// to log in and finish setup."
final adminInvitedProvider = Provider<List<CompanyModel>>((ref) {
  final all = ref.watch(allCompaniesAdminProvider).valueOrNull ?? [];
  return all
      .where((c) => c.onboardingSource == 'admin' && c.invitedAt != null)
      .toList();
});
