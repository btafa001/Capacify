import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/models/company_rating_model.dart';
import '../../../core/services/admin_provider.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../../core/utils/content_moderation.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _companySearch = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final pendingAsync = ref.watch(pendingCompaniesProvider);
    final pendingCount =
        pendingAsync.valueOrNull?.length ?? 0;
    final pendingRatingsAsync = ref.watch(pendingRatingsProvider);
    final pendingRatingsCount =
        pendingRatingsAsync.valueOrNull?.length ?? 0;
    final flaggedCapsAsync = ref.watch(flaggedCapacitiesProvider);
    final flaggedCompaniesAsync = ref.watch(flaggedCompaniesProvider);
    final flaggedCount = (flaggedCapsAsync.valueOrNull?.length ?? 0) +
        (flaggedCompaniesAsync.valueOrNull?.length ?? 0);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              l.adminPanelTitle,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Text(
                l.adminBadge,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 12),
          tabs: [
            Tab(text: l.overviewTab),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.verificationTab),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.ratingsTab),
                  if (pendingRatingsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pendingRatingsCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.moderationTab),
                  if (flaggedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$flaggedCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: l.companiesTabCaps),
          ],
        ),
      ),
      body: Stack(
        children: [
          const _DotGrid(),
          TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(),
              _VerificationTab(),
              _RatingsTab(),
              _ModerationTab(),
              _CompaniesTab(
                search: _companySearch,
                onSearch: (v) =>
                    setState(() => _companySearch = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  TAB 1 — OVERVIEW
// ─────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final allCompaniesAsync =
        ref.watch(allCompaniesAdminProvider);
    final allCapsAsync = ref.watch(capacitiesProvider);
    final pendingAsync =
        ref.watch(pendingCompaniesProvider);

    final companies = allCompaniesAsync.valueOrNull ?? [];
    final caps = allCapsAsync.valueOrNull ?? [];
    final pending = pendingAsync.valueOrNull ?? [];

    final verified =
        companies.where((cap) => cap.isVerified).length;
    final active = caps
        .where((cap) => cap.status == CapacityStatus.active)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              label: l.platformOverviewSection,
              icon: Icons.bar_chart),
          const SizedBox(height: 14),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l.navCompanies,
                  value: '${companies.length}',
                  icon: Icons.business_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: l.verifiedTitleCase,
                  value: '$verified',
                  icon: Icons.verified_outlined,
                  color: AppColors.live,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l.pendingLabel,
                  value: '${pending.length}',
                  icon: Icons.schedule_outlined,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: l.activePostsLabel,
                  value: '$active',
                  icon: Icons.rss_feed_rounded,
                  color: AppColors.distance,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          _SectionHeader(
              label: l.platformHealthSection,
              icon: Icons.health_and_safety_outlined),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                _HealthRow(
                  label: l.verificationRateLabel,
                  value: companies.isEmpty
                      ? '—'
                      : '${((verified / companies.length) * 100).round()}%',
                  good: companies.isEmpty ||
                      (verified / companies.length) > 0.3,
                ),
                Divider(color: c.border, height: 20),
                _HealthRow(
                  label: l.pendingReviewsLabel,
                  value: pending.isEmpty
                      ? l.noneLabel
                      : l.waitingCount(pending.length),
                  good: pending.isEmpty,
                ),
                Divider(color: c.border, height: 20),
                _HealthRow(
                  label: l.activeCapacitiesLabel,
                  value: '$active Posts live',
                  good: active > 0,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          _SectionHeader(
              label: l.setupAdminAccessSection,
              icon: Icons.info_outline),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.addNewAdminLabel,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.addAdminInstructions,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  TAB 2 — VERIFICATION QUEUE
// ─────────────────────────────────────────────────────

class _VerificationTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final pendingAsync = ref.watch(pendingCompaniesProvider);

    return pendingAsync.when(
      data: (pending) {
        if (pending.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.live.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 32,
                    color: AppColors.live,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.noPendingRequestsTitle,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.allCompaniesReviewedText,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.fromLTRB(24, 20, 24, 80),
          itemCount: pending.length,
          itemBuilder: (ctx, i) =>
              _VerificationCard(company: pending[i]),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary)),
      error: (e, _) => Center(
          child: Text(l.errorWithMessage(e),
              style:
                  const TextStyle(color: AppColors.error))),
    );
  }
}

class _VerificationCard extends ConsumerWidget {
  final CompanyModel company;
  const _VerificationCard({required this.company});

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          approve
              ? l.confirmVerificationTitle
              : l.rejectVerificationTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: Text(
          approve
              ? l.verificationApprovedBody(company.name)
              : l.verificationRejectedBody(company.name),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              approve ? l.verifyCheckLabel : l.rejectLabel,
              style: TextStyle(
                color: approve
                    ? AppColors.live
                    : AppColors.error,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final svc = ref.read(adminServiceProvider);
      if (approve) {
        await svc.approveVerification(company.id);
      } else {
        await svc.rejectVerification(company.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve
              ? l.companyVerifiedSnackbar(company.name)
              : l.companyRejectedSnackbar(company.name)),
          backgroundColor:
              approve ? AppColors.live : AppColors.error,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.errorWithMessage(e)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final date = company.createdAt;
    final dateStr = date != null
        ? '${date.day}.${date.month}.${date.year}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amber left strip
          Container(
            width: 4,
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          company.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: AppColors.accent
                                  .withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule,
                                size: 11,
                                color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              l.verificationPendingBadge,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Info rows
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _InfoChip(
                          icon: Icons.build_outlined,
                          text: company.trade.isEmpty
                              ? '—'
                              : l.tradeName(company.trade)),
                      _InfoChip(
                          icon: Icons.location_on_outlined,
                          text: company.city.isEmpty
                              ? '—'
                              : company.city),
                      _InfoChip(
                          icon: Icons.mail_outline,
                          text: company.email.isEmpty
                              ? '—'
                              : company.email),
                      if (company.vatNumber.isNotEmpty)
                        _InfoChip(
                            icon: Icons.receipt_outlined,
                            text: company.vatNumber),
                      _InfoChip(
                          icon: Icons.calendar_today_outlined,
                          text: l.sinceDateLabel(dateStr)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirm(context,
                              ref, approve: true),
                          icon: const Icon(
                              Icons.check_circle_outline,
                              size: 16),
                          label: Text(
                            l.verifyButtonCaps,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.live,
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 40),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirm(context,
                              ref, approve: false),
                          icon: const Icon(Icons.cancel_outlined,
                              size: 16),
                          label: Text(
                            l.rejectButtonCaps,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(
                                color: AppColors.error),
                            minimumSize:
                                const Size(double.infinity, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  TAB — RATINGS MODERATION QUEUE
// ─────────────────────────────────────────────────────

class _RatingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final pendingAsync = ref.watch(pendingRatingsProvider);

    return pendingAsync.when(
      data: (pending) {
        if (pending.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.live.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 32,
                    color: AppColors.live,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.noPendingRatingsTitle,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.allRatingsReviewedText,
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
          itemCount: pending.length,
          itemBuilder: (ctx, i) =>
              _RatingApprovalCard(rating: pending[i]),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary)),
      error: (e, _) => Center(
          child: Text(l.errorWithMessage(e),
              style:
                  const TextStyle(color: AppColors.error))),
    );
  }
}

class _RatingApprovalCard extends ConsumerWidget {
  final CompanyRatingModel rating;
  const _RatingApprovalCard({required this.rating});

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required bool approve,
  }) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          approve
              ? l.confirmApproveRatingTitle
              : l.confirmRejectRatingTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: Text(
          approve
              ? l.ratingApprovedBody(
                  rating.raterCompanyName, rating.ratedCompanyName)
              : l.ratingRejectedBody(
                  rating.raterCompanyName, rating.ratedCompanyName),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              approve ? l.approveCheckLabel : l.rejectLabel,
              style: TextStyle(
                color: approve
                    ? AppColors.live
                    : AppColors.error,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final svc = ref.read(adminServiceProvider);
      if (approve) {
        await svc.approveRating(rating.id);
      } else {
        await svc.rejectRating(rating.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve
              ? l.ratingApprovedSnackbar
              : l.ratingRejectedSnackbar),
          backgroundColor:
              approve ? AppColors.live : AppColors.error,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.errorWithMessage(e)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final date = rating.updatedAt ?? rating.createdAt;
    final dateStr = date != null
        ? '${date.day}.${date.month}.${date.year}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amber left strip
          Container(
            width: 4,
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: rating.raterCompanyName,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              TextSpan(
                                text: '  ${l.ratingForLabel}  ',
                                style: TextStyle(
                                  color: c.textTertiary,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: rating.ratedCompanyName,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: AppColors.accent
                                  .withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule,
                                size: 11,
                                color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              l.pendingReviewBadge,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  StarRatingDisplay(rating: rating.rating.toDouble(), size: 16),

                  if (rating.comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      rating.comment,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],

                  if (containsBlockedContent(rating.comment)) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 13, color: AppColors.error),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            l.containsFlaggedLanguageWarning,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      text: l.sinceDateLabel(dateStr)),

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirm(context,
                              ref, approve: true),
                          icon: const Icon(
                              Icons.check_circle_outline,
                              size: 16),
                          label: Text(
                            l.approveButtonCaps,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.live,
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 40),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirm(context,
                              ref, approve: false),
                          icon: const Icon(Icons.cancel_outlined,
                              size: 16),
                          label: Text(
                            l.rejectButtonCaps,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(
                                color: AppColors.error),
                            minimumSize:
                                const Size(double.infinity, 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  TAB — MODERATION (FLAGGED CONTENT)
// ─────────────────────────────────────────────────────

class _ModerationTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final capsAsync = ref.watch(flaggedCapacitiesProvider);
    final companiesAsync = ref.watch(flaggedCompaniesProvider);

    if (capsAsync.isLoading || companiesAsync.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (capsAsync.hasError) {
      return Center(
          child: Text(l.errorWithMessage(capsAsync.error!),
              style: const TextStyle(color: AppColors.error)));
    }
    if (companiesAsync.hasError) {
      return Center(
          child: Text(l.errorWithMessage(companiesAsync.error!),
              style: const TextStyle(color: AppColors.error)));
    }

    final caps = capsAsync.valueOrNull ?? [];
    final companies = companiesAsync.valueOrNull ?? [];

    if (caps.isEmpty && companies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.live.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 32,
                color: AppColors.live,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.noPendingModerationTitle,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.allContentReviewedText,
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final items = <Widget>[
      ...caps.map((cap) => _FlaggedCapacityCard(capacity: cap)),
      ...companies.map((co) => _FlaggedCompanyCard(company: co)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      children: items,
    );
  }
}

class _FlaggedCapacityCard extends ConsumerWidget {
  final CapacityModel capacity;
  const _FlaggedCapacityCard({required this.capacity});

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          l.confirmApproveContentTitle,
          style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17),
        ),
        content: Text(
          l.approveContentBody,
          style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.approveCheckLabel,
                style: const TextStyle(
                    color: AppColors.live, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminServiceProvider).approveFlaggedCapacity(capacity.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.contentApprovedSnackbar),
          backgroundColor: AppColors.live,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.errorWithMessage(e)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final date = capacity.createdAt;
    final dateStr =
        date != null ? '${date.day}.${date.month}.${date.year}' : '—';

    return _ModerationCardShell(
      typeLabel: l.flaggedPostingTypeLabel,
      title: capacity.autoTitle(l),
      subtitle: capacity.companyName,
      body: capacity.description,
      dateStr: dateStr,
      l: l,
      onApprove: () => _approve(context, ref),
    );
  }
}

class _FlaggedCompanyCard extends ConsumerWidget {
  final CompanyModel company;
  const _FlaggedCompanyCard({required this.company});

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          l.confirmApproveContentTitle,
          style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17),
        ),
        content: Text(
          l.approveContentBody,
          style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.approveCheckLabel,
                style: const TextStyle(
                    color: AppColors.live, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminServiceProvider).approveFlaggedCompany(company.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.contentApprovedSnackbar),
          backgroundColor: AppColors.live,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.errorWithMessage(e)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final date = company.createdAt;
    final dateStr =
        date != null ? '${date.day}.${date.month}.${date.year}' : '—';

    return _ModerationCardShell(
      typeLabel: l.flaggedCompanyTypeLabel,
      title: company.name,
      subtitle: l.tradeName(company.trade),
      body: company.description,
      dateStr: dateStr,
      l: l,
      onApprove: () => _approve(context, ref),
    );
  }
}

class _ModerationCardShell extends StatelessWidget {
  final String typeLabel;
  final String title;
  final String subtitle;
  final String body;
  final String dateStr;
  final AppLocalizations l;
  final VoidCallback onApprove;

  const _ModerationCardShell({
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.dateStr,
    required this.l,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: c.textTertiary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: AppColors.accent.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag_outlined,
                                size: 11, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              l.pendingReviewBadge,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 13, height: 1.4),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      text: l.sinceDateLabel(dateStr)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(
                        l.approveButtonCaps,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.live,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  TAB 3 — ALL COMPANIES
// ─────────────────────────────────────────────────────

class _CompaniesTab extends ConsumerWidget {
  final String search;
  final ValueChanged<String> onSearch;

  const _CompaniesTab(
      {required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final allAsync = ref.watch(allCompaniesAdminProvider);

    return allAsync.when(
      data: (all) {
        final q = search.toLowerCase();
        final filtered = q.isEmpty
            ? all
            : all
                .where((cap) =>
                    cap.name.toLowerCase().contains(q) ||
                    cap.city.toLowerCase().contains(q) ||
                    cap.trade.toLowerCase().contains(q) ||
                    cap.email.toLowerCase().contains(q))
                .toList();

        return Column(
          children: [
            // Search bar
            Container(
              color: c.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                onChanged: onSearch,
                style: TextStyle(
                    color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l.searchEllipsisHint,
                  hintStyle: TextStyle(
                      color: c.textTertiary,
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: c.textTertiary, size: 20),
                  filled: true,
                  fillColor: c.background,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // Company count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Text(
                    l.companiesCountBadge(filtered.length),
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l.noResultsText,
                        style: TextStyle(
                            color: c.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          16, 4, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) =>
                          _CompanyAdminRow(
                              company: filtered[i]),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary)),
      error: (e, _) => Center(
          child: Text(l.errorWithMessage(e),
              style:
                  const TextStyle(color: AppColors.error))),
    );
  }
}

class _CompanyAdminRow extends ConsumerWidget {
  final CompanyModel company;
  const _CompanyAdminRow({required this.company});

  Future<void> _revokeOrReset(
      BuildContext context, WidgetRef ref) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          l.revokeVerificationTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: Text(
          l.revokeVerificationBody(company.name),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.revokeButton,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(adminServiceProvider)
          .revokeVerification(company.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(l.verificationRevokedSnackbar(company.name)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorWithMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final status = company.verificationStatus;
    final Color statusColor = status == 'verified'
        ? AppColors.live
        : status == 'pending'
            ? AppColors.accent
            : c.textTertiary;
    final String statusLabel = status == 'verified'
        ? l.verifiedLabel
        : status == 'pending'
            ? l.pendingBadgeCaps
            : l.registeredBadge;
    final IconData statusIcon = status == 'verified'
        ? Icons.verified
        : status == 'pending'
            ? Icons.schedule
            : Icons.how_to_reg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                company.name.isNotEmpty
                    ? company.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${company.trade.isEmpty ? "—" : l.tradeName(company.trade)}  ·  ${company.city.isEmpty ? "—" : company.city}',
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: statusColor.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon,
                    size: 11, color: statusColor),
                const SizedBox(width: 3),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Revoke button (only for verified)
          if (status == 'verified') ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  size: 18, color: c.textTertiary),
              tooltip: l.revokeVerificationTooltip,
              onPressed: () =>
                  _revokeOrReset(context, ref),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  SHARED HELPER WIDGETS
// ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader(
      {required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, size: 18, color: color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final bool good;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.good,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Icon(
          good
              ? Icons.check_circle_outline
              : Icons.warning_amber_outlined,
          size: 16,
          color: good ? AppColors.live : AppColors.accent,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: good ? AppColors.live : AppColors.accent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
//  DOT GRID BACKGROUND
// ─────────────────────────────────────────────────────

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _DotGridPainter()),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
