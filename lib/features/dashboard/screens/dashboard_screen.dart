import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../company/screens/company_profile_screen.dart';
import '../../company/screens/company_directory_screen.dart';
import '../../opportunities/screens/live_capacity_feed_screen.dart';
import '../../opportunities/screens/create_capacity_screen.dart';
import '../../opportunities/screens/my_capacities_screen.dart';
import '../../profile/screens/my_profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../landing/screens/landing_screen.dart';
import '../../../core/services/admin_provider.dart';
import '../../admin/screens/admin_screen.dart';
import '../../../shared/widgets/capacify_logo.dart';
import '../../../shared/widgets/theme_switcher.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _userPostalCode;
  String? _userEmail;
  CapacityType? _activeTypeFilter;
  int _feedResetKey = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _refreshLiveFeed() => setState(() => _feedResetKey++);

  Future<void> _loadUserData() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      setState(() => _userEmail = user.email);
      final company = await ref.read(companyServiceProvider).getCompanyByOwner(user.uid);
      if (company != null && mounted) setState(() => _userPostalCode = company.postalCode);
    }
  }

  Future<void> _navigateToMyCapacities() async {
    final l = AppLocalizations.of(context);
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final company = await ref.read(companyServiceProvider).getCompanyByOwner(user.uid);
    if (!mounted) return;
    if (company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noCompanyFirst), backgroundColor: AppColors.error),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => MyCapacitiesScreen(company: company)));
  }

  Future<void> _navigateToCreateCapacity() async {
    final l = AppLocalizations.of(context);
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final company = await ref.read(companyServiceProvider).getCompanyByOwner(user.uid);
    if (!mounted) return;
    if (company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noCompanyFirst2), backgroundColor: AppColors.error),
      );
      return;
    }
    final size = MediaQuery.of(context).size;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => Align(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width < 600 ? 0 : 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size.width < 600 ? size.width : 720, maxHeight: size.height * 0.88),
            child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CreateCapacityScreen(company: company)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final sidebar = _SideBar(
      userEmail: _userEmail,
      onMyCapacities: _navigateToMyCapacities,
      onCreateCapacity: _navigateToCreateCapacity,
      onRefreshFeed: _refreshLiveFeed,
      isMobile: isMobile,
    );
    final mainContent = Column(
      children: [
        _TopBar(userEmail: _userEmail, isMobile: isMobile),
        Expanded(
          child: LiveCapacityFeedScreen(
            key: ValueKey(_feedResetKey),
            userPostalCode: _userPostalCode,
            initialTypeFilter: _activeTypeFilter,
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: c.background,
      drawer: isMobile ? Drawer(backgroundColor: c.surface, width: 280, child: sidebar) : null,
      body: isMobile ? mainContent : Row(children: [sidebar, Expanded(child: mainContent)]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateCapacity,
        backgroundColor: AppColors.primary,
        elevation: 10,
        icon: const Icon(Icons.flash_on, color: Colors.white, size: 22),
        label: Text(l.fabPostCapacity, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8)),
      ),
    );
  }
}

// ─── SIDEBAR ──────────────────────────────────────────────────────────────────

class _SideBar extends ConsumerWidget {
  final String? userEmail;
  final VoidCallback onMyCapacities;
  final VoidCallback onCreateCapacity;
  final VoidCallback onRefreshFeed;
  final bool isMobile;

  const _SideBar({
    required this.userEmail,
    required this.onMyCapacities,
    required this.onCreateCapacity,
    required this.onRefreshFeed,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final capacitiesAsync = ref.watch(capacitiesProvider);
    final activeCount = capacitiesAsync.maybeWhen(data: (list) => list.length, orElse: () => 0);
    final favoriteCount = ref.watch(userFavoriteCapacitiesProvider).maybeWhen(data: (list) => list.length, orElse: () => 0);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final adminPendingCount = ref.watch(pendingCompaniesProvider).valueOrNull?.length ?? 0;

    return Container(
      width: 236,
      height: double.infinity,
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Fixed top: logo ──────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CapacifyWordmark(symbolSize: 54, fontSize: 32, textColor: c.textPrimary),
                const SizedBox(height: 4),
                const Text('Hamburg', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Text('$activeCount ${l.active}', style: const TextStyle(fontSize: 13, color: AppColors.live, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: c.border, height: 1),
          const SizedBox(height: 12),

          // ── Fixed: post button ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isMobile) Navigator.of(context).pop();
                  onCreateCapacity();
                },
                icon: const Icon(Icons.flash_on, size: 18, color: Colors.white),
                label: Text(l.navPostCapacity, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 46), elevation: 6, shadowColor: AppColors.primary.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Scrollable nav items (fills remaining space, scrolls if tight) ──
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NavItem(
                    icon: Icons.rss_feed_rounded,
                    label: l.navLiveFeed,
                    isActive: true,
                    onTap: () {
                      if (isMobile) Navigator.of(context).pop();
                      onRefreshFeed();
                    },
                  ),
                  _NavItem(
                    icon: Icons.business_outlined,
                    label: l.navCompanies,
                    onTap: () {
                      if (isMobile) Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyDirectoryScreen()));
                    },
                  ),
                  _NavItem(
                    icon: Icons.list_alt_outlined,
                    label: l.navMyListings,
                    onTap: () {
                      if (isMobile) Navigator.of(context).pop();
                      onMyCapacities();
                    },
                  ),
                  _NavItemWithBadge(
                    icon: Icons.favorite_outlined,
                    label: l.navFavorites,
                    badge: favoriteCount > 0 ? favoriteCount : null,
                    onTap: () {
                      if (isMobile) Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                    },
                  ),
                  _NavItem(
                    icon: Icons.analytics_outlined,
                    label: l.navAnalytics,
                    comingSoon: true,
                  ),
                  if (isAdmin)
                    _NavItemWithBadge(
                      icon: Icons.admin_panel_settings_outlined,
                      label: l.navAdmin,
                      badge: adminPendingCount > 0 ? adminPendingCount : null,
                      onTap: () {
                        if (isMobile) Navigator.of(context).pop();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Fixed bottom section ─────────────────────────
          Divider(color: c.border, height: 1),

          // Microcopy
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
            child: Text(l.sidebarQuote, style: TextStyle(fontSize: 11, color: c.textTertiary, fontStyle: FontStyle.italic, height: 1.5)),
          ),

          Divider(color: c.border, height: 1),

          // Feedback button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: GestureDetector(
              onTap: () => showDialog(context: context, builder: (_) => const _FeedbackDialog()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.feedback_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.sidebarFeedback, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),

          // Logout button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: GestureDetector(
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LandingScreen()),
                    (route) => false,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 16, color: AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.menuLogout, style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── NAV ITEMS ────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final bool comingSoon;

  const _NavItem({required this.icon, required this.label, this.onTap, this.isActive = false, this.comingSoon = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: comingSoon ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? AppColors.primary : (comingSoon ? c.textTertiary : c.textSecondary)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(fontSize: 15, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal, color: isActive ? AppColors.primary : (comingSoon ? c.textTertiary : c.textSecondary)),
              ),
            ),
            if (comingSoon) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Text(l.comingSoonTag, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.textTertiary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItemWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;
  final VoidCallback onTap;

  const _NavItemWithBadge({required this.icon, required this.label, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textSecondary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c.textSecondary))),
            if (badge != null && badge! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── TOP BAR ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final String? userEmail;
  final bool isMobile;

  const _TopBar({this.userEmail, this.isMobile = false});

  List<PopupMenuEntry<String>> _menuItems(BuildContext context, AppLocalizations l) {
    final c = AppColors.of(context);
    return [
    PopupMenuItem(
      value: 'profile',
      child: Row(children: [const Icon(Icons.person_outline, color: AppColors.primary, size: 18), const SizedBox(width: 12), Text(l.menuProfile, style: TextStyle(color: c.textPrimary, fontSize: 15))]),
    ),
    PopupMenuItem(
      value: 'company',
      child: Row(children: [const Icon(Icons.domain_outlined, color: AppColors.primary, size: 18), const SizedBox(width: 12), Text(l.menuCompany, style: TextStyle(color: c.textPrimary, fontSize: 15))]),
    ),
    PopupMenuItem(
      value: 'settings',
      child: Row(children: [const Icon(Icons.settings_outlined, color: AppColors.primary, size: 18), const SizedBox(width: 12), Text(l.menuSettings, style: TextStyle(color: c.textPrimary, fontSize: 15))]),
    ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: 'logout',
      child: Row(children: [const Icon(Icons.logout, color: AppColors.error, size: 18), const SizedBox(width: 12), Text(l.menuLogout, style: const TextStyle(color: AppColors.error, fontSize: 15))]),
    ),
    ];
  }

  Future<void> _onMenuSelected(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'profile':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen()));
        break;
      case 'company':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyProfileScreen()));
        break;
      case 'settings':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
      case 'logout':
        await ref.read(authServiceProvider).signOut();
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingScreen()),
            (route) => false,
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);

    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.menu, color: c.textPrimary, size: 22), onPressed: () => Scaffold.of(context).openDrawer(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            CapacifyWordmark(symbolSize: 30, fontSize: 22, textColor: c.textPrimary),
            const SizedBox(width: 6),
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
            const Spacer(),
            const LanguageSwitcher(compact: true),
            const SizedBox(width: 8),
            const ThemeSwitcher(),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              color: c.surface,
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
              onSelected: (v) => _onMenuSelected(context, ref, v),
              itemBuilder: (ctx) => _menuItems(ctx, l),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withOpacity(0.25),
                child: Text(
                  userEmail?.isNotEmpty == true ? userEmail![0].toUpperCase() : 'U',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.topBarTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: 0.8)),
                  Text(l.topBarSubtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
              ),
            ],
          ),
          const Spacer(),
          const LanguageSwitcher(compact: true),
          const SizedBox(width: 8),
          const ThemeSwitcher(),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            color: c.surface,
            offset: const Offset(0, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
            onSelected: (v) => _onMenuSelected(context, ref, v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withOpacity(0.3),
                    child: Text(
                      userEmail?.isNotEmpty == true ? userEmail![0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userEmail?.split('@')[0] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      Text(l.accountSettings, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more, size: 16, color: AppColors.primary),
                ],
              ),
            ),
            itemBuilder: (ctx) => _menuItems(ctx, l),
          ),
        ],
      ),
    );
  }
}

// ─── LIVE STATS BAR ───────────────────────────────────────────────────────────

class _LiveStatsBar extends ConsumerWidget {
  final CapacityType? activeFilter;
  final Function(CapacityType?) onFilterChanged;
  final bool isMobile;

  const _LiveStatsBar({required this.activeFilter, required this.onFilterChanged, this.isMobile = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final capacitiesAsync = ref.watch(capacitiesProvider);

    return capacitiesAsync.when(
      data: (capacities) {
        final total = capacities.length;
        final offers = capacities.where((cap) => cap.type == CapacityType.offer).length;
        final needs  = capacities.where((cap) => cap.type == CapacityType.need).length;
        final liveNow = capacities.where((cap) => cap.isLive).length;

        final pills = [
          _ClickableStatPill(icon: Icons.circle, label: '$liveNow LIVE', color: AppColors.live, isActive: false, onTap: () => onFilterChanged(null)),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: c.border),
          const SizedBox(width: 6),
          _ClickableStatPill(
            icon: Icons.volunteer_activism_outlined,
            label: '$offers ${l.statsAvailable}',
            color: AppColors.offerColor,
            isActive: activeFilter == CapacityType.offer,
            onTap: () => onFilterChanged(activeFilter == CapacityType.offer ? null : CapacityType.offer),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: c.border),
          const SizedBox(width: 6),
          _ClickableStatPill(
            icon: Icons.search_outlined,
            label: '$needs ${l.statsNeeded}',
            color: AppColors.needColor,
            isActive: activeFilter == CapacityType.need,
            onTap: () => onFilterChanged(activeFilter == CapacityType.need ? null : CapacityType.need),
          ),
        ];

        return Container(
          decoration: BoxDecoration(color: c.background, border: Border(bottom: BorderSide(color: c.border))),
          child: isMobile
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: pills))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(children: [...pills, const Spacer(), Text(l.totalLabel(total), style: TextStyle(fontSize: 13, color: c.textTertiary))]),
                ),
        );
      },
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox(height: 40),
    );
  }
}

class _ClickableStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _ClickableStatPill({required this.icon, required this.label, required this.color, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? Border.all(color: color.withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: isActive ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── FEEDBACK DIALOG ──────────────────────────────────────────────────────────

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    final uri = Uri(scheme: 'mailto', path: 'hello@capacify.de', queryParameters: {'subject': 'Capacify Feedback', 'body': msg});
    try { await launchUrl(uri); } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Icon(Icons.feedback_outlined, size: 22, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.feedbackTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(l.feedbackSubtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l.feedbackBody, style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.6)),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 5,
                autofocus: true,
                style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.5),
                decoration: InputDecoration(hintText: l.feedbackHint, alignLabelWithHint: true),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.mail_outline, size: 13, color: c.textTertiary),
                  const SizedBox(width: 5),
                  Text('hello@capacify.de', style: TextStyle(fontSize: 12, color: c.textTertiary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.cancel, style: TextStyle(color: c.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(l.feedbackSend, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shadowColor: AppColors.primary.withOpacity(0.4),
                      elevation: 6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
