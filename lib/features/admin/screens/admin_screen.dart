import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/models/company_rating_model.dart';
import '../../../core/services/admin_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/admin_onboarding_provider.dart';
import '../../../core/models/capacity_model.dart';
import 'admin_onboarding_screen.dart';
import 'contact_requests_tab.dart';
import '../../company/screens/company_detail_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../../core/utils/content_moderation.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/report_provider.dart';
import '../../../core/models/report_model.dart';

class AdminScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const AdminScreen({super.key, this.embedded = false});

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
    AnalyticsService.logScreenView('Admin');
    _tabs = TabController(length: 8, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _migrating = false;

  // One-off: migrate legacy posts (strip embedded identity → locked sidecar,
  // backfill trust signals, normalize trades). Admin-gated by Firestore rules.
  Future<void> _runLegacyMigration() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.migrateLegacyTitle),
        content: Text(l.migrateLegacyConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l.migrateLegacyRun),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _migrating = true);
    try {
      final r = await ref.read(capacityServiceProvider).migrateLegacyIdentityPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.migrateLegacyResult(
              r['migrated'] ?? 0, r['skipped'] ?? 0, r['failed'] ?? 0)),
          backgroundColor: (r['failed'] ?? 0) > 0 ? AppColors.error : AppColors.success,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  // One-off: close the two PII holes on data that already exists. New writes
  // are already correct — this fixes the documents written before that.
  //  1. Company contact (email/phone/address/postalCode) still sitting inline
  //     on the world-readable companies doc → moved to the gated
  //     companyContacts sidecar.
  //  2. Exact poster rating/response figures still on public posts → re-banded,
  //     so an anonymous post can't be joined back against the directory.
  // Both are idempotent and safe to re-run; both are admin-gated by Firestore
  // rules, so this runs entirely client-side like the legacy migration above.
  Future<void> _runPrivacyBackfill() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.privacyBackfillTitle),
        content: Text(l.privacyBackfillConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l.privacyBackfillRun),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _migrating = true);
    try {
      final contacts =
          await ref.read(companyServiceProvider).migrateContactsToGatedSidecar();
      final posts =
          await ref.read(capacityServiceProvider).rebandPublicPostSignals();
      if (mounted) {
        final failed = (contacts['failed'] ?? 0) + (posts['failed'] ?? 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.privacyBackfillResult(
              contacts['migrated'] ?? 0, posts['migrated'] ?? 0, failed)),
          backgroundColor: failed > 0 ? AppColors.error : AppColors.success,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
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
    final pendingReportsCount = ref.watch(pendingReportsProvider).length;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: c.textPrimary),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
        actions: [
          IconButton(
            tooltip: l.migrateLegacyTooltip,
            onPressed: _migrating ? null : _runLegacyMigration,
            icon: _migrating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(Icons.cleaning_services_outlined, color: c.textSecondary),
          ),
          IconButton(
            tooltip: l.privacyBackfillTooltip,
            onPressed: _migrating ? null : _runPrivacyBackfill,
            icon: Icon(Icons.shield_outlined, color: c.textSecondary),
          ),
        ],
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
            Tab(text: l.onboardTab),
            Tab(text: l.contactRequestsTab),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.reportsTab),
                  if (pendingReportsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pendingReportsCount',
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
              _OnboardingTab(),
              const ContactRequestsTab(),
              _ReportsTab(),
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
    final companies = ref.watch(allCompaniesAdminProvider).valueOrNull ?? [];
    final caps = ref.watch(capacitiesProvider).valueOrNull ?? [];
    final ownerMap = ref.watch(capacityOwnerMapProvider).valueOrNull ?? {};
    final pending = ref.watch(pendingCompaniesProvider).valueOrNull ?? [];
    final pendingRatings = ref.watch(pendingRatingsProvider).valueOrNull ?? [];
    final openModerations =
        (ref.watch(flaggedCapacitiesProvider).valueOrNull?.length ?? 0) +
            (ref.watch(flaggedCompaniesProvider).valueOrNull?.length ?? 0) +
            pendingRatings.length;

    final now = DateTime.now();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));
    bool within(DateTime? t, int days) => t != null && t.isAfter(daysAgo(days));
    bool inactiveSince(CompanyModel x, int days) =>
        x.lastActiveAt == null || x.lastActiveAt!.isBefore(daysAgo(days));
    int pct(int a, int b) => b == 0 ? 0 : ((a / b) * 100).round();

    // ── Companies ──
    final totalCompanies = companies.length;
    final verified = companies.where((x) => x.isVerified).length;
    final active30 = companies.where((x) => within(x.lastActiveAt, 30)).length;
    final newRegs7 = companies.where((x) => within(x.createdAt, 7)).length;
    final newRegs30 = companies.where((x) => within(x.createdAt, 30)).length;
    final inactive30 = companies.where((x) => inactiveSince(x, 30)).length;
    final inactive60 = companies.where((x) => inactiveSince(x, 60)).length;
    final profileComplete = companies.where((x) => x.isProfileComplete).length;

    // ── Listings (active = live in feed) ──
    final activeCaps = caps.where((x) => x.isActiveInFeed).toList();
    final active = activeCaps.length;
    final newListings7 = caps.where((x) => within(x.createdAt, 7)).length;
    final newListings30 = caps.where((x) => within(x.createdAt, 30)).length;
    final offers =
        activeCaps.where((x) => x.type == CapacityType.offer).length;
    final needs = activeCaps.where((x) => x.type == CapacityType.need).length;

    // ── Posts per company (via the owner sidecar map) ──
    final postsPerCompany = <String, int>{};
    for (final cap in caps) {
      final owner = ownerMap[cap.id];
      if (owner != null) postsPerCompany[owner] = (postsPerCompany[owner] ?? 0) + 1;
    }
    final neverPosted =
        companies.where((x) => !postsPerCompany.containsKey(x.id)).toList();
    final companiesWith1 = totalCompanies - neverPosted.length;
    final companiesWith2 =
        companies.where((x) => (postsPerCompany[x.id] ?? 0) >= 2).length;
    final avgPerCompany = totalCompanies == 0 ? 0.0 : caps.length / totalCompanies;
    final avgPerDay = newListings30 / 30.0;
    final ages = activeCaps
        .where((x) => x.createdAt != null)
        .map((x) => now.difference(x.createdAt!).inDays)
        .toList();
    final avgAge =
        ages.isEmpty ? 0 : (ages.reduce((a, b) => a + b) / ages.length).round();

    // ── Trade performance ──
    final listingsByTrade = <String, int>{};
    for (final cap in caps) {
      listingsByTrade[cap.trade] = (listingsByTrade[cap.trade] ?? 0) + 1;
    }
    final companiesByTrade = <String, int>{};
    for (final comp in companies) {
      for (final t in comp.trades) {
        companiesByTrade[t] = (companiesByTrade[t] ?? 0) + 1;
      }
    }
    final topTrades = listingsByTrade.keys.toList()
      ..sort((a, b) => (listingsByTrade[b] ?? 0).compareTo(listingsByTrade[a] ?? 0));
    final maxTradeListings =
        topTrades.isEmpty ? 1 : (listingsByTrade[topTrades.first] ?? 1);

    // ── Most active region ──
    final companiesByCity = <String, int>{};
    for (final comp in companies) {
      if (comp.city.trim().isNotEmpty) {
        companiesByCity[comp.city] = (companiesByCity[comp.city] ?? 0) + 1;
      }
    }
    String? topCity;
    if (companiesByCity.isNotEmpty) {
      topCity = (companiesByCity.keys.toList()
            ..sort((a, b) => (companiesByCity[b] ?? 0).compareTo(companiesByCity[a] ?? 0)))
          .first;
    }

    // ── AI insights (generated from the real numbers) ──
    final insights = <String>[];
    if (topTrades.isNotEmpty && caps.isNotEmpty) {
      insights.add(l.insightTopTrade(
          l.tradeName(topTrades.first), pct(listingsByTrade[topTrades.first] ?? 0, caps.length)));
    }
    if (neverPosted.isNotEmpty) insights.add(l.insightNoListing(neverPosted.length));
    if (topCity != null) insights.add(l.insightTopCity(topCity));
    if (totalCompanies > 0) insights.add(l.insightVerification(pct(verified, totalCompanies)));
    if (newRegs30 > 0) insights.add(l.insightGrowth(newRegs30));
    if (inactive30 > 0) insights.add(l.insightInactive(inactive30));
    final shownInsights = insights.take(5).toList();

    // ── Reactivation lists ──
    final postedOnceInactive = companies
        .where((x) => (postsPerCompany[x.id] ?? 0) == 1 && inactiveSince(x, 30))
        .toList();
    final incompleteProfiles =
        companies.where((x) => !x.isProfileComplete).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              label: l.platformOverviewSection,
              icon: Icons.bar_chart),
          const SizedBox(height: 14),

          // KPI grid — 6 operational cards
          Row(children: [
            Expanded(child: _StatCard(label: l.kpiRegistered, value: '$totalCompanies', icon: Icons.business_outlined, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: l.kpiVerified, value: '$verified', icon: Icons.verified_outlined, color: AppColors.live)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(label: l.kpiActive30, value: '$active30', icon: Icons.bolt_outlined, color: AppColors.accent)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: l.kpiActiveListings, value: '$active', icon: Icons.rss_feed_rounded, color: AppColors.distance)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(label: l.kpiNewRegs30, value: '$newRegs30', icon: Icons.person_add_alt, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: l.kpiNewListings30, value: '$newListings30', icon: Icons.add_chart_outlined, color: AppColors.live)),
          ]),

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
                _StatusRow(
                  label: l.verificationRateLabel,
                  value: '${pct(verified, totalCompanies)}%',
                  color: pct(verified, totalCompanies) >= 50
                      ? AppColors.live
                      : pct(verified, totalCompanies) >= 25
                          ? AppColors.accent
                          : AppColors.error,
                ),
                Divider(color: c.border, height: 18),
                _StatusRow(
                  label: l.activeCapacitiesLabel,
                  value: '$active',
                  color: active > 0 ? AppColors.live : AppColors.error,
                ),
                Divider(color: c.border, height: 18),
                _StatusRow(
                  label: l.healthCompaniesNoListing,
                  value: '${neverPosted.length}',
                  color: neverPosted.isEmpty
                      ? AppColors.live
                      : neverPosted.length * 2 < totalCompanies
                          ? AppColors.accent
                          : AppColors.error,
                ),
                Divider(color: c.border, height: 18),
                _StatusRow(
                  label: l.healthInactive30,
                  value: '$inactive30',
                  color: inactive30 == 0
                      ? AppColors.live
                      : inactive30 * 2 < totalCompanies
                          ? AppColors.accent
                          : AppColors.error,
                ),
                Divider(color: c.border, height: 18),
                _StatusRow(
                  label: l.healthInactive60,
                  value: '$inactive60',
                  color: inactive60 == 0 ? AppColors.live : AppColors.error,
                ),
                Divider(color: c.border, height: 18),
                _StatusRow(
                  label: l.healthOpenVerifications,
                  value: '${pending.length}',
                  color: pending.isEmpty
                      ? AppColors.live
                      : pending.length <= 5
                          ? AppColors.accent
                          : AppColors.error,
                ),
                Divider(color: c.border, height: 18),
                _StatusRow(
                  label: l.healthOpenModerations,
                  value: '$openModerations',
                  color: openModerations == 0
                      ? AppColors.live
                      : openModerations <= 3
                          ? AppColors.accent
                          : AppColors.error,
                ),
              ],
            ),
          ),

          // ── GROWTH ──
          const SizedBox(height: 28),
          _SectionHeader(label: l.dashGrowthSection, icon: Icons.trending_up_rounded),
          const SizedBox(height: 14),
          _DashCard(children: [
            _DashMetric(label: l.growthRegs7, value: '$newRegs7'),
            _DashMetric(label: l.growthRegs30, value: '$newRegs30'),
            _DashMetric(label: l.growthListings7, value: '$newListings7'),
            _DashMetric(label: l.growthListings30, value: '$newListings30'),
            _DashMetric(label: l.growthAvgPerCompany, value: avgPerCompany.toStringAsFixed(1)),
            _DashMetric(label: l.growthMin1, value: '$companiesWith1'),
            _DashMetric(label: l.growthMin2, value: '$companiesWith2'),
          ]),

          // ── TRADE PERFORMANCE ──
          const SizedBox(height: 28),
          _SectionHeader(label: l.dashGewerkeSection, icon: Icons.construction_outlined),
          const SizedBox(height: 14),
          _DashCard(children: [
            if (topTrades.isEmpty)
              _EmptyLine(text: l.insightNeedMore)
            else
              ...topTrades.take(10).map((t) => _TradeBar(
                    trade: t,
                    listings: listingsByTrade[t] ?? 0,
                    companies: companiesByTrade[t] ?? 0,
                    fraction: (listingsByTrade[t] ?? 0) / maxTradeListings,
                  )),
          ]),

          // ── ONBOARDING FUNNEL ──
          const SizedBox(height: 28),
          _SectionHeader(label: l.dashOnboardingSection, icon: Icons.filter_alt_outlined),
          const SizedBox(height: 14),
          _DashCard(children: [
            _FunnelBar(label: l.funnelRegistered, count: totalCompanies, fraction: 1.0),
            _FunnelBar(label: l.funnelProfileComplete, count: profileComplete, fraction: totalCompanies == 0 ? 0 : profileComplete / totalCompanies),
            _FunnelBar(label: l.funnelFirstListing, count: companiesWith1, fraction: totalCompanies == 0 ? 0 : companiesWith1 / totalCompanies),
            _FunnelBar(label: l.funnelSecondListing, count: companiesWith2, fraction: totalCompanies == 0 ? 0 : companiesWith2 / totalCompanies),
            _FunnelBar(label: l.funnelActive30, count: active30, fraction: totalCompanies == 0 ? 0 : active30 / totalCompanies),
          ]),

          // ── MARKETPLACE LIQUIDITY ──
          const SizedBox(height: 28),
          _SectionHeader(label: l.dashLiquiditySection, icon: Icons.water_drop_outlined),
          const SizedBox(height: 14),
          _DashCard(children: [
            _DashMetric(label: l.kpiActiveListings, value: '$active'),
            _DashMetric(label: l.liqOffers, value: '$offers', valueColor: AppColors.offerColor),
            _DashMetric(label: l.liqNeeds, value: '$needs', valueColor: AppColors.needColor),
            _DashMetric(label: l.liqAvgPerDay, value: avgPerDay.toStringAsFixed(1)),
            _DashMetric(label: l.liqAvgDuration, value: l.daysShort(avgAge)),
          ]),

          // ── AI INSIGHTS ──
          const SizedBox(height: 28),
          _SectionHeader(label: l.dashInsightsSection, icon: Icons.auto_awesome_outlined),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: shownInsights.isEmpty
                  ? [_EmptyLine(text: l.insightNeedMore)]
                  : shownInsights.map((s) => _InsightItem(text: s)).toList(),
            ),
          ),

          // ── CONVERSION ──
          const SizedBox(height: 28),
          _SectionHeader(label: l.dashConversionSection, icon: Icons.filter_list_rounded),
          const SizedBox(height: 14),
          _DashCard(children: [
            _DashMetric(label: l.convVisitors, value: l.convVisitorsHint, valueColor: c.textTertiary),
            _FunnelBar(label: l.funnelRegistered, count: totalCompanies, fraction: 1.0),
            _FunnelBar(label: l.convFirstListing, count: companiesWith1, fraction: totalCompanies == 0 ? 0 : companiesWith1 / totalCompanies),
            _FunnelBar(label: l.convSecondListing, count: companiesWith2, fraction: totalCompanies == 0 ? 0 : companiesWith2 / totalCompanies),
          ]),

          // ── ACTION CENTER (reactivation) ──
          const SizedBox(height: 28),
          _SectionHeader(label: l.dashActionSection, icon: Icons.campaign_outlined),
          const SizedBox(height: 14),
          if (neverPosted.isEmpty && postedOnceInactive.isEmpty && incompleteProfiles.isEmpty)
            _DashCard(children: [_EmptyLine(text: l.actionAllClear)])
          else ...[
            _ActionGroup(title: l.actionNeverPosted, icon: Icons.post_add_outlined, color: AppColors.error, companies: neverPosted),
            if (postedOnceInactive.isNotEmpty) const SizedBox(height: 12),
            _ActionGroup(title: l.actionPostedInactive, icon: Icons.hotel_outlined, color: AppColors.accent, companies: postedOnceInactive),
            if (incompleteProfiles.isNotEmpty) const SizedBox(height: 12),
            _ActionGroup(title: l.actionIncompleteProfile, icon: Icons.person_outline, color: AppColors.distance, companies: incompleteProfiles),
          ],
        ],
      ),
    );
  }
}

// ── Dashboard building blocks ──

class _DashCard extends StatelessWidget {
  final List<Widget> children;
  const _DashCard({required this.children});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );
  }
}

class _DashMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DashMetric({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: valueColor ?? c.textPrimary)),
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatusRow({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary))),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
    ]);
  }
}

class _TradeBar extends StatelessWidget {
  final String trade;
  final int listings;
  final int companies;
  final double fraction;
  const _TradeBar({required this.trade, required this.listings, required this.companies, required this.fraction});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l.tradeName(trade), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary), overflow: TextOverflow.ellipsis)),
          Text(l.gewerkeStat(listings, companies), style: TextStyle(fontSize: 12, color: c.textTertiary)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.03, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: c.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ]),
    );
  }
}

class _FunnelBar extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  const _FunnelBar({required this.label, required this.count, required this.fraction});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary))),
          Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.textPrimary)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: c.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation(AppColors.live),
          ),
        ),
      ]),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String text;
  const _InsightItem({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.45))),
      ]),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine({required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 13, color: c.textTertiary)),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<CompanyModel> companies;
  const _ActionGroup({required this.title, required this.icon, required this.color, required this.companies});

  Future<void> _contact(CompanyModel comp) async {
    if (comp.email.trim().isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: comp.email.trim());
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (companies.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text('${companies.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          ...companies.take(4).map((comp) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(comp.name.isEmpty ? comp.email : comp.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      if (comp.city.isNotEmpty)
                        Text(comp.city, style: TextStyle(fontSize: 11.5, color: c.textTertiary)),
                    ]),
                  ),
                  TextButton(
                    onPressed: comp.email.trim().isEmpty ? null : () => _contact(comp),
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(l.actionContact, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => showCompanyDetailDialog(context, comp),
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(l.actionCheckProfile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
              )),
          if (companies.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.actionMore(companies.length - 4), style: TextStyle(fontSize: 12, color: c.textTertiary)),
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
      error: (e, _) => AppErrorState(
        error: e,
        onRetry: () => ref.invalidate(pendingCompaniesProvider),
      ),
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
      // IntrinsicHeight + stretch lets the strip fill the card without an
      // infinite-height child (which broke ListView layout: only one card
      // was ever laid out in the release build).
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amber left strip
          Container(
            width: 4,
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
                      TextButton(
                        onPressed: () => showCompanyDetailDialog(context, company),
                        style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text(l.actionCheckProfile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 4),
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
                          text: company.trades.isEmpty
                              ? '—'
                              : company.trades.map((t) => l.tradeName(t)).join(', ')),
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

                  // VIES result banner — when the applicant ran the automatic
                  // check, show whether the VAT is valid + the registered name,
                  // so the founder can give the Freigabe with confidence.
                  if (company.vatValid) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.live.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.live.withOpacity(0.35)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.verified_outlined, size: 14, color: AppColors.live),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            company.vatVerifiedName.isNotEmpty
                                ? l.viesConfirmedWithName(company.vatVerifiedName)
                                : l.viesConfirmed,
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.live),
                          ),
                        ),
                      ]),
                    ),
                  ],

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
    final pendingAsync = ref.watch(pendingRatingsProvider);
    return _RatingsList(
      pendingAsync: pendingAsync,
      onRetry: () => ref.invalidate(pendingRatingsProvider),
    );
  }
}

class _RatingsList extends StatelessWidget {
  final AsyncValue<List<CompanyRatingModel>> pendingAsync;
  final VoidCallback onRetry;
  const _RatingsList({required this.pendingAsync, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);

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
      error: (e, _) => AppErrorState(error: e, onRetry: onRetry),
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(l.deleteRatingConfirmTitle, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
        content: Text(l.deleteRatingConfirmBody, style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteButton, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // Admin delete recomputes the aggregate immediately (rater self-delete
      // can't touch the aggregate — it self-heals on next moderation).
      await ref.read(adminServiceProvider)
          .deleteRatingAndRecompute(ratingId: rating.id, companyId: rating.companyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.ratingDeletedSnackbar),
          backgroundColor: AppColors.error,
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
    final ratedCompany = ref.watch(companyByIdProvider(rating.companyId)).valueOrNull;
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
      // Same IntrinsicHeight fix as the verification card (see above).
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amber left strip
          Container(
            width: 4,
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
                      TextButton(
                        onPressed: ratedCompany == null ? null : () => showCompanyDetailDialog(context, ratedCompany),
                        style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text(l.actionCheckProfile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 4),
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

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _delete(context, ref),
                      icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.error),
                      label: Text(l.deleteRatingButton, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
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
      return AppErrorState(
        error: capsAsync.error!,
        onRetry: () => ref.invalidate(flaggedCapacitiesProvider),
      );
    }
    if (companiesAsync.hasError) {
      return AppErrorState(
        error: companiesAsync.error!,
        onRetry: () => ref.invalidate(flaggedCompaniesProvider),
      );
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
      // Posts are anonymous — show the district instead of a company name.
      subtitle: capacity.location,
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

    // enforceCompanyIntegrity (functions/index.js) tags WHY this got flagged —
    // surface the impersonation/duplicate-VAT cases specifically since "this
    // might not be who they say they are" needs a different admin judgment
    // call than a moderation hit on the description text.
    final String subtitle;
    if (company.flagReason == 'impersonation') {
      subtitle = l.impersonationFlagNotice(company.flagDetail);
    } else if (company.flagReason == 'duplicate_vat') {
      subtitle = l.duplicateVatFlagNotice(company.flagDetail);
    } else {
      subtitle = company.trades.map((t) => l.tradeName(t)).join(', ');
    }

    return _ModerationCardShell(
      typeLabel: l.flaggedCompanyTypeLabel,
      title: company.name,
      subtitle: subtitle,
      body: company.description,
      dateStr: dateStr,
      l: l,
      onApprove: () => _approve(context, ref),
      onViewProfile: () => showCompanyDetailDialog(context, company),
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
  // Only companies have a profile to view — capacities are anonymous posts,
  // so _FlaggedCapacityCard never passes this and keeps the single full-width
  // Approve button.
  final VoidCallback? onViewProfile;

  const _ModerationCardShell({
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.dateStr,
    required this.l,
    required this.onApprove,
    this.onViewProfile,
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
      // Same IntrinsicHeight fix as the verification card (see above).
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
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
                  if (onViewProfile != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onViewProfile,
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: Text(
                              l.actionCheckProfile,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.4,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
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
                    )
                  else
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  TAB — USER-FILED REPORTS
// ─────────────────────────────────────────────────────
//
// Distinct from _ModerationTab above: that one shows content the SYSTEM
// auto-flagged (moderation.js / enforceCompanyIntegrity). This shows reports
// a USER filed via ReportService.submitReport (chat_screen.dart,
// live_capacity_feed_screen.dart) — previously written to Firestore but never
// surfaced anywhere in the admin UI (getAllReports() was dead code), so
// day-one abuse reports sat unseen indefinitely.
class _ReportsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final reportsAsync = ref.watch(allReportsProvider);

    if (reportsAsync.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (reportsAsync.hasError) {
      return AppErrorState(
        error: reportsAsync.error!,
        onRetry: () => ref.invalidate(allReportsProvider),
      );
    }

    // Pending first (newest first within each group), then already-handled
    // ones below — an admin should never have to scroll past a backlog of
    // resolved reports to find the one that still needs attention.
    final all = reportsAsync.valueOrNull ?? [];
    final pending = all.where((r) => r.status == 'pending').toList();
    final handled = all.where((r) => r.status != 'pending').toList();

    if (all.isEmpty) {
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
              l.noReportsTitle,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.allReportsHandledText,
              style: TextStyle(color: c.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      children: [
        ...pending.map((r) => _ReportCard(report: r)),
        ...handled.map((r) => _ReportCard(report: r)),
      ],
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final ReportModel report;
  const _ReportCard({required this.report});

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, String status) async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(reportServiceProvider).setReportStatus(report.id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'resolved'
              ? l.reportResolvedSnackbar
              : l.reportDismissedSnackbar),
          backgroundColor:
              status == 'resolved' ? AppColors.live : AppColors.textSecondary,
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
    final date = report.createdAt;
    final dateStr = '${date.day}.${date.month}.${date.year}';
    final isPending = report.status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? AppColors.accent.withOpacity(0.35)
              : c.border,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: isPending ? AppColors.accent : c.border,
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
                            l.reportedPostingTypeLabel,
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
                            report.capacityTitle.isNotEmpty
                                ? report.capacityTitle
                                : report.companyName,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isPending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.border.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              report.status == 'resolved'
                                  ? l.reportStatusResolved
                                  : l.reportStatusDismissed,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: c.textTertiary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.companyName,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.reason.label,
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        text: l.sinceDateLabel(dateStr)),
                    if (isPending) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (report.companyId.isNotEmpty)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final co = await ref
                                      .read(companyServiceProvider)
                                      .getCompanyStream(report.companyId)
                                      .first;
                                  if (co != null && context.mounted) {
                                    showCompanyDetailDialog(context, co);
                                  }
                                },
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 16),
                                label: Text(
                                  l.actionCheckProfile,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                ),
                              ),
                            ),
                          if (report.companyId.isNotEmpty)
                            const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _setStatus(context, ref, 'dismissed'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 40),
                              ),
                              child: Text(
                                l.dismissReportLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _setStatus(context, ref, 'resolved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.live,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 40),
                                elevation: 0,
                              ),
                              child: Text(
                                l.markResolvedLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
                    cap.trades.any((t) => t.toLowerCase().contains(q)) ||
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
      error: (e, _) => AppErrorState(
        error: e,
        onRetry: () => ref.invalidate(allCompaniesAdminProvider),
      ),
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

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          l.suspendCompanyTitle,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.suspendCompanyBody(company.name),
              style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: l.suspendReasonHint,
                hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.suspendButton, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminServiceProvider).suspendCompany(company.id, reasonController.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.companySuspendedSnackbar(company.name)),
          backgroundColor: AppColors.error,
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

  Future<void> _unsuspend(BuildContext context, WidgetRef ref) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          l.unsuspendCompanyTitle,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
        ),
        content: Text(
          l.unsuspendCompanyBody(company.name),
          style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.unsuspendButton, style: const TextStyle(color: AppColors.live, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminServiceProvider).unsuspendCompany(company.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.companyUnsuspendedSnackbar(company.name)),
          backgroundColor: AppColors.live,
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

    return GestureDetector(
      onTap: () => showCompanyDetailDialog(context, company),
      child: Container(
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
                  '${company.trades.isEmpty ? "—" : company.trades.map((t) => l.tradeName(t)).join(", ")}  ·  ${company.city.isEmpty ? "—" : company.city}',
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

          // Suspended badge
          if (company.suspended) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.10),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.error.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, size: 11, color: AppColors.error),
                  const SizedBox(width: 3),
                  Text(
                    l.suspendedBadge,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.error,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],

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

          // Suspend / unsuspend toggle. The "suspend" (idle) state used to be
          // c.textTertiary — a muted adaptive grey meant for secondary TEXT,
          // not an actionable icon; at 18px it was near-invisible against
          // both the dark surface and (per live report) the light one too.
          // AppColors.warning is a fixed, high-contrast amber already used
          // elsewhere as a caution accent (password-strength, email-verify
          // banner) — reads clearly in both themes and doesn't collide with
          // AppColors.error, which the badge above uses for "already
          // suspended" (this icon means "click to suspend", not that state).
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              company.suspended ? Icons.play_circle_outline : Icons.block,
              size: 18,
              color: company.suspended ? AppColors.live : AppColors.warning,
            ),
            tooltip: company.suspended ? l.unsuspendCompanyTooltip : l.suspendCompanyTooltip,
            onPressed: () => company.suspended ? _unsuspend(context, ref) : _suspend(context, ref),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
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

// ─────────────────────────────────────────────────────
//  TAB — ADMIN-ASSISTED ONBOARDING
// ─────────────────────────────────────────────────────

class _OnboardingTab extends ConsumerWidget {
  Future<void> _sendInvite(
    BuildContext context,
    WidgetRef ref,
    CompanyModel company,
  ) async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(
            company.email,
            languageCode: 'de',
            continueUrl: 'https://capacify-mvp.web.app/',
          );
      await ref.read(adminOnboardingServiceProvider).markInvited(company.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.onboardInviteSentSnackbar),
          backgroundColor: AppColors.success,
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
    final notInvited = ref.watch(adminCreatedNotInvitedProvider);
    final invited = ref.watch(adminInvitedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin access setup — moved off the Dashboard (rarely needed), kept
          // here under Admin Management, collapsed so it takes no space.
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(left: 4, bottom: 12),
              leading: Icon(Icons.admin_panel_settings_outlined, size: 18, color: c.textSecondary),
              title: Text(l.setupAdminAccessSection,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c.textTertiary, letterSpacing: 0.6)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.addNewAdminLabel, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(l.addAdminInstructions, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.6)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Start-onboarding prompt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.onboardIntroTitle,
                    style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(l.onboardIntroBody,
                    style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminOnboardingScreen()),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(l.onboardStartButton, style: const TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Follow-up: created but not yet invited
          Text(l.onboardNotInvitedSection,
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          if (notInvited.isEmpty)
            Text(l.onboardNoFollowupsText, style: TextStyle(color: c.textTertiary, fontSize: 13))
          else
            ...notInvited.map((company) => _OnboardingFollowupCard(
                  company: company,
                  trailing: TextButton.icon(
                    onPressed: () => _sendInvite(context, ref, company),
                    icon: const Icon(Icons.mail_outline, size: 14, color: AppColors.primary),
                    label: Text(l.onboardSendInviteAction,
                        style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                )),

          const SizedBox(height: 24),

          // Follow-up: invited, waiting on the company
          Text(l.onboardInvitedSection,
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          if (invited.isEmpty)
            Text(l.onboardNoFollowupsText, style: TextStyle(color: c.textTertiary, fontSize: 13))
          else
            ...invited.map((company) => _OnboardingFollowupCard(
                  company: company,
                  trailing: const Icon(Icons.schedule, size: 16, color: AppColors.accent),
                )),
        ],
      ),
    );
  }
}

class _OnboardingFollowupCard extends StatelessWidget {
  final CompanyModel company;
  final Widget trailing;
  const _OnboardingFollowupCard({required this.company, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company.name.isEmpty ? company.email : company.name,
                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(company.email, style: TextStyle(color: c.textTertiary, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
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
