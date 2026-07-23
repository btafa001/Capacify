import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/contact_request_provider.dart';
import '../../../core/services/chat_provider.dart';
import '../../../core/services/credit_provider.dart';
import '../../../core/services/fcm_provider.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/company_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../company/screens/company_profile_screen.dart';
import '../../company/screens/company_directory_screen.dart';
import '../../opportunities/screens/live_capacity_feed_screen.dart';
import '../../opportunities/screens/create_capacity_screen.dart';
import '../../opportunities/screens/my_capacities_screen.dart';
import '../../opportunities/screens/my_requests_screen.dart';
import '../../opportunities/screens/received_requests_screen.dart';
import '../../messaging/screens/messages_inbox_screen.dart';
import '../../notifications/notification_bell.dart';
import '../../profile/screens/my_profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../favorites/screens/favorites_screen.dart';
import '../../landing/screens/landing_screen.dart';
import '../../../core/services/admin_provider.dart';
import '../../admin/screens/admin_screen.dart';
import '../../../shared/widgets/capacify_logo.dart';
import '../../../shared/widgets/invite_dialog.dart';
import '../../../shared/widgets/theme_switcher.dart';
import '../../../shared/widgets/email_verification_banner.dart';
import '../../../core/services/analytics_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.section = AppSection.feed});

  /// The section the URL asked for (`/app/favoriten` → favorites). The route is
  /// the source of truth on desktop, which is what makes refresh, browser back
  /// and a pasted link all land in the same place.
  final AppSection section;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _userPostalCode;
  String? _userEmail;
  CompanyModel? _userCompany;
  CapacityType? _activeTypeFilter;
  int _feedResetKey = 0;
  // Active section for the app-shell. Desktop: sidebar stays pinned, content
  // swaps in place. Mobile: bottom-bar sections swap in place too; drawer-only
  // sections still push. Held so the mobile drawer can be closed programmatically
  // when a nav tap comes from it (see _navigate).
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late _Section _section = widget.section;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('Dashboard');
    _loadUserData();
  }

  // The shell is deliberately given one page key for `/app` and `/app/:section`
  // (see app_router.dart), so a sidebar click reuses this State rather than
  // remounting the whole dashboard — which means the new section arrives here
  // as a widget update, not a fresh initState.
  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section != oldWidget.section && widget.section != _section) {
      setState(() => _section = widget.section);
    }
  }

  void _refreshLiveFeed() => setState(() => _feedResetKey++);

  Future<void> _loadUserData() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      setState(() => _userEmail = user.email);
      // Ensure the Vermittlung wallet exists + is reset for the current month,
      // so the sidebar balance is live from first load.
      ref.read(creditServiceProvider).ensureWallet(user.uid);
      // Fire-and-forget: browser permission prompt + FCM token registration.
      // Fully non-fatal (see FcmService) — never blocks dashboard load.
      ref.read(fcmServiceProvider).registerForUser(user.uid);
      final company = await ref.read(companyServiceProvider).getCompanyByOwner(user.uid);
      if (company != null && mounted) {
        setState(() {
          _userPostalCode = company.postalCode;
          _userCompany = company;
        });
      }
    }
  }

  // The sections that live in the mobile bottom nav bar (M9), in bar order.
  // These swap IN PLACE on mobile so the persistent bar never pushes a page
  // over itself; every other (drawer-only) section still opens as a pushed page.
  static const List<_Section> _barSections = [
    _Section.feed,
    _Section.contacts,
    _Section.messages,
    _Section.requests,
  ];

  // Both platforms drive the pinned/mobile shell by URL: context.go updates the
  // route, which rebuilds this screen with the new section (see didUpdateWidget)
  // and swaps the shell body in place — so a section survives refresh + browser
  // back. On desktop every section works this way. On mobile the four bottom-bar
  // sections do too (so the bar stays put); the remaining drawer-only sections
  // keep opening as a pushed full page with a back button, which reads naturally
  // on a phone. Either entry point closes the drawer first if it's open.
  void _navigate(_Section s) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState!.closeDrawer();
    }
    if (!isMobile || _barSections.contains(s)) {
      if (s == _section && s == _Section.feed) {
        _refreshLiveFeed(); // re-tapping Feed refreshes it rather than no-op
      } else {
        context.go(s.location);
      }
      return;
    }
    final w = _screenFor(s, embedded: false);
    if (w != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    }
  }

  // The screen for a section. `embedded` hides its own back button so it reads
  // as pinned-shell content rather than a pushed page.
  Widget? _screenFor(_Section s, {required bool embedded}) {
    switch (s) {
      case _Section.feed:
        return null; // handled by the feed column
      case _Section.companies:
        return CompanyDirectoryScreen(embedded: embedded);
      case _Section.listings:
        final co = _userCompany;
        return co == null ? null : MyCapacitiesScreen(company: co, embedded: embedded);
      case _Section.requests:
        return MyRequestsScreen(embedded: embedded);
      case _Section.contacts:
        return ReceivedRequestsScreen(embedded: embedded);
      case _Section.messages:
        return MessagesInboxScreen(embedded: embedded);
      case _Section.favorites:
        return FavoritesScreen(embedded: embedded);
      case _Section.admin:
        // The sidebar only offers this to admins, but the section is a URL now
        // (/app/admin) and anyone can type one. Firestore rules make it a wall
        // of denied reads rather than a leak for a non-admin, but returning
        // null (→ the feed) is the honest answer. Deliberately not a "no
        // access" page: the admin area isn't advertised.
        final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
        return isAdmin ? AdminScreen(embedded: embedded) : null;
    }
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
    // Gate posting behind a complete profile: an anonymous post is only
    // trustworthy if the firm behind it is real and reachable (phone, address,
    // trades, description). This also curbs spam/orphan posts from empty
    // accounts. Missing → route to the profile instead of the composer.
    if (!company.isProfileComplete) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final cc = AppColors.of(ctx);
          return AlertDialog(
            backgroundColor: cc.surface,
            title: Text(l.completeProfileToPostTitle,
                style: TextStyle(color: cc.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
            content: Text(l.completeProfileMissingFieldsBody(company.missingCompletenessFieldsLabel(l)),
                style: TextStyle(color: cc.textSecondary, fontSize: 14, height: 1.5)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text(l.completeProfileToPostCta,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          );
        },
      );
      if (go == true && mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CompanyProfileScreen()));
      }
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
      active: _section,
      onNavigate: _navigate,
      onCreateCapacity: _navigateToCreateCapacity,
      isMobile: isMobile,
    );
    final feedColumn = Column(
      children: [
        _TopBar(userEmail: _userEmail, isMobile: isMobile),
        if (_userCompany != null)
          _GettingStartedCard(
            company: _userCompany!,
            onProfile: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyProfileScreen()));
              _loadUserData();
            },
            onPost: _navigateToCreateCapacity,
            onAlerts: () async {
              await ref.read(companyServiceProvider).setEmailOptIn(_userCompany!.id, true);
              _loadUserData();
            },
          ),
        Expanded(
          child: LiveCapacityFeedScreen(
            key: ValueKey(_feedResetKey),
            userPostalCode: _userPostalCode,
            initialTypeFilter: _activeTypeFilter,
          ),
        ),
      ],
    );
    // Shell content, shared by both layouts: the feed (which carries its own top
    // bar), or the selected section's screen embedded in place. On mobile the
    // four bottom-bar sections swap in here too, so the bar stays put.
    final shellContent = _section == _Section.feed
        ? feedColumn
        : (_screenFor(_section, embedded: true) ?? feedColumn);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.background,
      drawer: isMobile ? Drawer(backgroundColor: c.surface, width: 280, child: sidebar) : null,
      // Persistent across every section/device — posting and contacting are
      // both gated on email verification (firestore.rules), so this needs to
      // be visible no matter where in the app the user currently is.
      body: Column(
        children: [
          const EmailVerificationBanner(),
          Expanded(
            child: isMobile ? shellContent : Row(children: [sidebar, Expanded(child: shellContent)]),
          ),
        ],
      ),
      // Mobile bottom nav for the core loop (M9): Feed · Kontakte · Nachrichten ·
      // Anfragen. Desktop navigates from the pinned sidebar and has none.
      bottomNavigationBar: isMobile
          ? _MobileBottomNav(active: _section, onNavigate: _navigate)
          : null,
      // Quick-post FAB only on the feed now (both platforms render other sections
      // in place, so a "post capacity" FAB floating over Nachrichten/Kontakte
      // would be out of place; on the feed it's the primary action).
      floatingActionButton: _section == _Section.feed
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreateCapacity,
              backgroundColor: AppColors.primary,
              elevation: 10,
              icon: const Icon(Icons.flash_on, color: Colors.white, size: 22),
              label: Text(l.fabPostCapacity, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8)),
            )
          : null,
    );
  }
}

// Sections of the app-shell. Defined next to the router because each one is a
// URL now (`/app/favoriten`), not just an in-memory tab index — see AppSection.
typedef _Section = AppSection;

// ─── SIDEBAR ──────────────────────────────────────────────────────────────────

class _SideBar extends ConsumerWidget {
  final String? userEmail;
  final _Section active;
  final void Function(_Section) onNavigate;
  final VoidCallback onCreateCapacity;
  final bool isMobile;

  const _SideBar({
    required this.userEmail,
    required this.active,
    required this.onNavigate,
    required this.onCreateCapacity,
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
    // Aggregate every admin-actionable queue into one badge — verification,
    // content moderation, AND ratings moderation. Previously this only
    // reflected pending verifications, so flagged content / pending reviews
    // could sit unnoticed with no signal on the Admin nav item.
    final adminPendingCount = (ref.watch(pendingCompaniesProvider).valueOrNull?.length ?? 0) +
        (ref.watch(pendingRatingsProvider).valueOrNull?.length ?? 0) +
        (ref.watch(flaggedCapacitiesProvider).valueOrNull?.length ?? 0) +
        (ref.watch(flaggedCompaniesProvider).valueOrNull?.length ?? 0);
    // New interest awaiting the poster's response = 'pending' received requests.
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    // Needs-attention count for the Kontakte nav item — pending requests
    // (awaiting Accept/Decline) plus granted-but-not-yet-opened ones (auto-
    // granted visible/discreet posts skip 'pending' entirely, so without the
    // seenByPoster half this badge would never fire for those). This used to
    // just be the whole received list's length, so accepting a request — or
    // simply opening its chat — moved it from pending to granted but never
    // actually cleared it from the count; mirrors the same filter
    // my_capacities_screen.dart's per-post badge already uses correctly.
    final vermittlungCount = uid == null
        ? 0
        : (ref.watch(receivedRequestsProvider(uid)).valueOrNull ?? [])
            .where((r) => r.status == 'pending' || (r.status == 'granted' && !r.seenByPoster))
            .length;
    final unreadMessages = uid == null ? 0 : ref.watch(totalUnreadProvider(uid));

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

          const SizedBox(height: 12),

          // ── Scrollable nav items (fills remaining space, scrolls if tight) ──
          Expanded(
            child: _ScrollFadeList(
              backgroundColor: c.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NavItem(
                    icon: Icons.rss_feed_rounded,
                    label: l.navLiveFeed,
                    isActive: active == _Section.feed,
                    onTap: () => onNavigate(_Section.feed),
                  ),
                  _NavItem(
                    icon: Icons.business_outlined,
                    label: l.navCompanies,
                    isActive: active == _Section.companies,
                    onTap: () => onNavigate(_Section.companies),
                  ),
                  // ── Mein Netzwerk ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Text(l.netzwerkGroupLabel.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: c.textTertiary)),
                  ),
                  _NavItem(
                    icon: Icons.list_alt_outlined,
                    label: l.navAnzeigen,
                    indented: true,
                    isActive: active == _Section.listings,
                    onTap: () => onNavigate(_Section.listings),
                  ),
                  _NavItem(
                    icon: Icons.send_outlined,
                    label: l.navAnfragen,
                    indented: true,
                    isActive: active == _Section.requests,
                    onTap: () => onNavigate(_Section.requests),
                  ),
                  _NavItemWithBadge(
                    icon: Icons.handshake_outlined,
                    label: l.navKontakte,
                    indented: true,
                    isActive: active == _Section.contacts,
                    badge: vermittlungCount > 0 ? vermittlungCount : null,
                    onTap: () => onNavigate(_Section.contacts),
                  ),
                  _NavItemWithBadge(
                    icon: Icons.chat_bubble_outline,
                    label: l.messagesNavLabel,
                    isActive: active == _Section.messages,
                    badge: unreadMessages > 0 ? unreadMessages : null,
                    onTap: () => onNavigate(_Section.messages),
                  ),
                  // Favorites — a personal utility, kept at the end just above Admin.
                  _NavItemWithBadge(
                    icon: Icons.favorite_outlined,
                    label: l.navFavorites,
                    isActive: active == _Section.favorites,
                    badge: favoriteCount > 0 ? favoriteCount : null,
                    onTap: () => onNavigate(_Section.favorites),
                  ),
                  if (isAdmin)
                    _NavItemWithBadge(
                      icon: Icons.admin_panel_settings_outlined,
                      label: l.navAdmin,
                      isActive: active == _Section.admin,
                      badge: adminPendingCount > 0 ? adminPendingCount : null,
                      onTap: () => onNavigate(_Section.admin),
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

          // Invite a company — zero-cost liquidity lever (grows the network).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _SidebarActionButton(
              icon: Icons.person_add_alt_1_rounded,
              label: l.sidebarInvite,
              accent: AppColors.primary,
              onTap: () => showInviteDialog(context, companyId: uid),
            ),
          ),

          // Feedback button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _SidebarActionButton(
              icon: Icons.feedback_outlined,
              label: l.sidebarFeedback,
              accent: AppColors.primary,
              onTap: () => showDialog(context: context, builder: (_) => const _FeedbackDialog()),
            ),
          ),

          // Logout button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: _SidebarActionButton(
              icon: Icons.logout,
              label: l.menuLogout,
              accent: AppColors.error,
              showChevron: false,
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LandingScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MOBILE BOTTOM NAV (M9) ────────────────────────────────────────────────────

/// The phone-first core loop as a persistent bottom bar: Feed · Kontakte ·
/// Nachrichten · Anfragen. Kontakte and Nachrichten carry the same
/// needs-attention badges as their sidebar rows. Everything else stays in the
/// drawer, reachable from the feed top bar's hamburger.
class _MobileBottomNav extends ConsumerWidget {
  final _Section active;
  final void Function(_Section) onNavigate;
  const _MobileBottomNav({required this.active, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    // Same badge math as the sidebar: pending received requests plus granted-
    // but-unseen ones for Kontakte, total unread for Nachrichten.
    final vermittlungCount = uid == null
        ? 0
        : (ref.watch(receivedRequestsProvider(uid)).valueOrNull ?? [])
            .where((r) =>
                r.status == 'pending' ||
                (r.status == 'granted' && !r.seenByPoster))
            .length;
    final unreadMessages = uid == null ? 0 : ref.watch(totalUnreadProvider(uid));

    final items = <_BottomNavSpec>[
      _BottomNavSpec(_Section.feed, Icons.rss_feed_rounded, l.navLiveFeed),
      _BottomNavSpec(_Section.contacts, Icons.handshake_outlined, l.navKontakte,
          badge: vermittlungCount),
      _BottomNavSpec(
          _Section.messages, Icons.chat_bubble_outline, l.messagesNavLabel,
          badge: unreadMessages),
      _BottomNavSpec(_Section.requests, Icons.send_outlined, l.navAnfragen),
    ];

    return Material(
      color: c.surface,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final it in items)
                  Expanded(
                    child: _BottomNavButton(
                      spec: it,
                      isActive: active == it.section,
                      onTap: () => onNavigate(it.section),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavSpec {
  final _Section section;
  final IconData icon;
  final String label;
  final int badge;
  const _BottomNavSpec(this.section, this.icon, this.label, {this.badge = 0});
}

/// One bottom-bar destination. InkWell (not a bare GestureDetector) so it
/// carries a button role + focus node for the always-on semantics tree — see
/// AGENTS.md.
class _BottomNavButton extends StatelessWidget {
  final _BottomNavSpec spec;
  final bool isActive;
  final VoidCallback onTap;
  const _BottomNavButton(
      {required this.spec, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = isActive ? AppColors.primary : c.textTertiary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconWithBadge(icon: spec.icon, color: color, badge: spec.badge),
            const SizedBox(height: 3),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badge;
  const _IconWithBadge(
      {required this.icon, required this.color, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final ic = Icon(icon, size: 23, color: color);
    if (badge <= 0) return ic;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ic,
        Positioned(
          right: -9,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── SCROLL-FADE WRAPPER (sidebar "more below" hint) ───────────────────────────

/// Scrolls [child] and overlays a subtle bottom fade while there's unscrolled
/// content below — a lightweight "more items below" cue for the sidebar nav
/// list, since it can grow long (Admin tab, badges) and the user otherwise has
/// no hint that Feedback/invite/logout aren't the last items. Fades itself out
/// once scrolled to the bottom, and never appears at all if everything fits.
class _ScrollFadeList extends StatefulWidget {
  final Widget child;
  final Color backgroundColor;
  const _ScrollFadeList({required this.child, required this.backgroundColor});

  @override
  State<_ScrollFadeList> createState() => _ScrollFadeListState();
}

class _ScrollFadeListState extends State<_ScrollFadeList> {
  final _controller = ScrollController();
  bool _showFade = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recompute);
    // maxScrollExtent is unknown until the first layout pass completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recompute() {
    if (!mounted || !_controller.hasClients) return;
    final canScrollMore =
        _controller.position.maxScrollExtent - _controller.offset > 4;
    if (canScrollMore != _showFade) setState(() => _showFade = canScrollMore);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            controller: _controller,
            physics: const ClampingScrollPhysics(),
            child: widget.child,
          ),
        ),
        if (_showFade)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 22,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [widget.backgroundColor, widget.backgroundColor.withOpacity(0)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── NAV ITEMS ────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool indented;
  final VoidCallback? onTap;

  const _NavItem({required this.icon, required this.label, this.onTap, this.isActive = false, this.indented = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: indented ? 24 : 10, right: 10, top: 1, bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? AppColors.primary : c.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              // No maxLines/ellipsis/softWrap constraint — matches
              // _NavItemWithBadge below, which already wraps naturally.
              // 'Gesendete Anfragen' previously got truncated to one
              // ellipsized line here while 'Erhaltene Anfragen' (same length)
              // wrapped to two just because it used the other widget.
              child: Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal, color: isActive ? AppColors.primary : c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three tinted action rows at the foot of the sidebar (invite, feedback,
/// logout). Previously three copies of a bare [GestureDetector] wrapping a
/// [Container] — tappable by mouse and by nothing else: no focus node, no
/// keyboard activation, and nothing telling a screen reader these were
/// controls rather than decoration. Logging out was unreachable without a
/// pointer.
///
/// [InkWell] supplies the focus node and the Enter/Space handling; the border
/// swap makes focus *visible*, since the theme's default focus overlay all but
/// disappears on top of these already-tinted surfaces.
class _SidebarActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool showChevron;

  const _SidebarActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  State<_SidebarActionButton> createState() => _SidebarActionButtonState();
}

class _SidebarActionButtonState extends State<_SidebarActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // container + button with no label of its own, matching what
    // ButtonStyleButton does for every ElevatedButton in the app: the node is
    // announced as a button and the Text below supplies its name, so the two
    // can't drift apart or get read out twice.
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.accent.withOpacity(_focused ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? widget.accent : widget.accent.withOpacity(0.25),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: widget.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(fontSize: 13, color: widget.accent, fontWeight: FontWeight.w600),
                ),
              ),
              if (widget.showChevron)
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: widget.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;
  final bool indented;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItemWithBadge({required this.icon, required this.label, required this.onTap, this.badge, this.indented = false, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = isActive ? AppColors.primary : c.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: indented ? 24 : 10, right: 10, top: 1, bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal, color: fg))),
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

// ─── INCOMPLETE PROFILE BANNER ──────────────────────────────────────────────

/// The new-user activation path: a 3-step checklist (complete profile → post
/// first capacity → turn on alerts) that self-hides once all steps are done.
/// Post-count is live from the feed stream; profile/alerts come from the loaded
/// company. Tapping the alerts step opts in with one tap (explicit consent).
class _GettingStartedCard extends ConsumerWidget {
  final CompanyModel company;
  final VoidCallback onProfile;
  final VoidCallback onPost;
  final VoidCallback onAlerts;

  const _GettingStartedCard({
    required this.company,
    required this.onProfile,
    required this.onPost,
    required this.onAlerts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final postCount =
        ref.watch(myCapacitiesProvider(company.id)).valueOrNull?.length ?? 0;

    final profileDone = company.isProfileComplete;
    final postDone = postCount > 0;
    final alertsDone = company.emailOptIn;

    // Self-hide once the company is fully activated — no nagging afterwards.
    if (profileDone && postDone && alertsDone) return const SizedBox.shrink();

    final doneCount = [profileDone, postDone, alertsDone].where((x) => x).length;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      margin: EdgeInsets.fromLTRB(16, isMobile ? 8 : 12, 16, 0),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch_outlined, color: AppColors.primary, size: isMobile ? 15 : 18),
              const SizedBox(width: 8),
              Text(l.gettingStartedTitle,
                  style: TextStyle(fontSize: isMobile ? 12.5 : 14, fontWeight: FontWeight.w900, color: c.textPrimary)),
              const Spacer(),
              Text('$doneCount/3',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
          // Explanatory subtitle only on desktop — on mobile every pixel of
          // vertical space is precious, and the step labels are self-explanatory.
          if (!isMobile) ...[
            const SizedBox(height: 4),
            Text(l.gettingStartedSubtitle,
                style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4)),
          ],
          SizedBox(height: isMobile ? 4 : 10),
          _StepRow(label: l.gsStepProfile, done: profileDone, onTap: onProfile, compact: isMobile),
          _StepRow(label: l.gsStepPost, done: postDone, onTap: onPost, compact: isMobile),
          _StepRow(label: l.gsStepAlerts, done: alertsDone, onTap: onAlerts, compact: isMobile),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool done;
  final VoidCallback onTap;
  final bool compact;
  const _StepRow({required this.label, required this.done, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: done ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 7),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: compact ? 15 : 20, color: done ? AppColors.live : AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 12 : 13.5,
                  fontWeight: done ? FontWeight.w500 : FontWeight.w700,
                  color: done ? c.textTertiary : c.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!done) const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
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
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.menu, color: c.textPrimary, size: 22), tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip, onPressed: () => Scaffold.of(context).openDrawer(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            CapacifyWordmark(symbolSize: 30, fontSize: 22, textColor: c.textPrimary),
            const SizedBox(width: 6),
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
            const Spacer(),
            if (uid != null) NotificationBell(uid: uid),
            const LanguageSwitcher(iconOnly: true),
            const SizedBox(width: 8),
            const ThemeSwitcher(iconOnly: true),
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
          if (uid != null) NotificationBell(uid: uid),
          const SizedBox(width: 8),
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
    final uri = Uri(scheme: 'mailto', path: 'info@capacify.de', queryParameters: {'subject': 'Capacify Feedback', 'body': msg});
    try { await launchUrl(uri); } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
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
              if (isMobile) ...[
                Row(
                  children: [
                    Icon(Icons.mail_outline, size: 13, color: c.textTertiary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'info@capacify.de',
                        style: TextStyle(fontSize: 12, color: c.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.cancel, style: TextStyle(color: c.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_outlined, size: 16),
                        label: Text(l.feedbackSend, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shadowColor: AppColors.primary.withOpacity(0.4),
                          elevation: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Row(
                  children: [
                    Icon(Icons.mail_outline, size: 13, color: c.textTertiary),
                    const SizedBox(width: 5),
                    Text('info@capacify.de', style: TextStyle(fontSize: 12, color: c.textTertiary)),
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
