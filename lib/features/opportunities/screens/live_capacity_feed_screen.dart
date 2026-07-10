import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/report_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/saved_search_model.dart';
import '../../../core/services/saved_search_service.dart';
import '../../../shared/widgets/dot_grid_painter.dart';
import '../../../shared/widgets/interactions.dart';
import '../../../shared/widgets/trade_pill_dropdown.dart';
import '../../../shared/widgets/app_states.dart';
import 'capacity_detail_screen.dart';
import '../../../core/services/analytics_service.dart';
import '../widgets/interest_modal.dart';

final _viewedPosts = <String>{};
// Cards that have already played their entry fade — so they never re-animate on
// scroll (re-animation reads as cheap). Session-scoped, like _viewedPosts.
final _entryAnimated = <String>{};

class LiveCapacityFeedScreen extends ConsumerStatefulWidget {
  final String? userPostalCode;
  final CapacityType? initialTypeFilter;

  const LiveCapacityFeedScreen({
    super.key,
    this.userPostalCode,
    this.initialTypeFilter,
  });

  @override
  ConsumerState<LiveCapacityFeedScreen> createState() =>
      _LiveCapacityFeedScreenState();
}

class _LiveCapacityFeedScreenState
    extends ConsumerState<LiveCapacityFeedScreen> {
  static const _pageSize = 20;

  List<String> _selectedTrades = [];
  String _selectedWhen = 'Alle';
  String _selectedCrew = 'Alle'; // 'Alle' = any; otherwise a minimum crew size
  CapacityType? _typeFilter;
  bool _liveFilter = false;
  String _searchText = '';
  bool _sortByProximity = true;
  int _visibleCount = _pageSize;
  final _searchController = TextEditingController();

  /// Wraps a filter/search/sort change so the "Load more" position resets
  /// back to the first page — otherwise switching filters could leave you
  /// staring at however many items you'd revealed under the old filter.
  void _setFilter(VoidCallback fn) {
    setState(() {
      fn();
      _visibleCount = _pageSize;
    });
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('LiveCapacityFeed');
    _typeFilter = widget.initialTypeFilter;
  }

  @override
  void didUpdateWidget(LiveCapacityFeedScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTypeFilter != widget.initialTypeFilter) {
      _setFilter(() { _typeFilter = widget.initialTypeFilter; _liveFilter = false; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentSearch() async {
    final l = AppLocalizations.of(context);
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final crewMin = _selectedCrew == 'Alle' ? 0 : (int.tryParse(_selectedCrew) ?? 0);
    final type = _typeFilter == CapacityType.offer
        ? 'offer'
        : _typeFilter == CapacityType.need
            ? 'need'
            : 'all';
    try {
      await ref.read(savedSearchServiceProvider).save(SavedSearchModel(
            id: '',
            ownerId: uid,
            trades: _selectedTrades,
            when: _selectedWhen,
            crewMin: crewMin,
            type: type,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.searchSavedSnackbar), backgroundColor: AppColors.live));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.errorWithMessage(e)), backgroundColor: AppColors.error));
      }
    }
  }

  void _applySearch(SavedSearchModel s) {
    _searchController.clear();
    _setFilter(() {
      _selectedTrades = List<String>.from(s.trades);
      _selectedWhen = s.when;
      _selectedCrew = s.crewMin == 0 ? 'Alle' : '${s.crewMin}';
      _typeFilter = s.type == 'offer'
          ? CapacityType.offer
          : s.type == 'need'
              ? CapacityType.need
              : null;
      _searchText = '';
      _liveFilter = false;
    });
  }

  List<CapacityModel> _filterAndSort(List<CapacityModel> capacities, AppLocalizations l) {
    var filtered = capacities.where((c) {
      if (_liveFilter && !c.isLive) return false;
      if (_typeFilter != null && c.type != _typeFilter) return false;
      if (_selectedTrades.isNotEmpty && !_selectedTrades.contains(c.trade)) return false;
      if (_selectedWhen == 'NOW' && c.availabilityType != AvailabilityType.now) return false;
      if (_selectedWhen == 'WEEK' && c.availabilityType != AvailabilityType.thisWeek) return false;
      if (_selectedWhen == 'NEXT' && c.availabilityType != AvailabilityType.nextWeek) return false;
      if (_selectedCrew != 'Alle') {
        final min = int.tryParse(_selectedCrew) ?? 0;
        if (c.workerCount < min) return false;
      }
      if (_searchText.isNotEmpty) {
        final q = _searchText.toLowerCase();
        // Search matches only anonymized match fields — never identity.
        return c.title.toLowerCase().contains(q) ||
            c.location.toLowerCase().contains(q) ||
            c.trade.toLowerCase().contains(q) ||
            l.tradeName(c.trade).toLowerCase().contains(q);
      }
      return true;
    }).toList();

    if (_sortByProximity && widget.userPostalCode != null) {
      filtered.sort((a, b) {
        final dA = LocationService.estimateDistanceFromPostalCode(widget.userPostalCode!, a.location);
        final dB = LocationService.estimateDistanceFromPostalCode(widget.userPostalCode!, b.location);
        if (dA < 100 && dB < 100 && (dA - dB).abs() > 1) return dA.compareTo(dB);
        final tA = a.createdAt ?? DateTime(2000);
        final tB = b.createdAt ?? DateTime(2000);
        return tB.compareTo(tA);
      });
    } else {
      filtered.sort((a, b) {
        final tA = a.createdAt ?? DateTime(2000);
        final tB = b.createdAt ?? DateTime(2000);
        return tB.compareTo(tA);
      });
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final capacitiesAsync = ref.watch(capacitiesProvider);
    // Viewer's own trades → drives the "Passt zu Ihrem Profil" relevance badge.
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final viewerTrades = myUid == null
        ? const <String>[]
        : (ref.watch(myCompanyProvider(myUid)).valueOrNull?.trades ?? const <String>[]);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final tabGap = SizedBox(width: isMobile ? 4 : 8);

    return Column(
      children: [
        // ── TYPE TABS ──────────────────────────────────
        Container(
          color: c.surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              _TypeTab(
                label: l.tabAll,
                count: capacitiesAsync.maybeWhen(data: (v) => v.length, orElse: () => 0),
                isActive: _typeFilter == null && !_liveFilter,
                color: c.textPrimary,
                onTap: () => _setFilter(() { _typeFilter = null; _liveFilter = false; }),
              ),
              tabGap,
              _TypeTab(
                label: l.availableLabel,
                count: capacitiesAsync.maybeWhen(
                  data: (v) => v.where((c) => c.type == CapacityType.offer).length,
                  orElse: () => 0,
                ),
                isActive: _typeFilter == CapacityType.offer,
                color: AppColors.offerColor,
                onTap: () => _setFilter(() { _typeFilter = CapacityType.offer; _liveFilter = false; }),
              ),
              tabGap,
              _TypeTab(
                label: l.wantedLabel,
                count: capacitiesAsync.maybeWhen(
                  data: (v) => v.where((c) => c.type == CapacityType.need).length,
                  orElse: () => 0,
                ),
                isActive: _typeFilter == CapacityType.need,
                color: AppColors.needColor,
                onTap: () => _setFilter(() { _typeFilter = CapacityType.need; _liveFilter = false; }),
              ),
              tabGap,
              _TypeTab(
                label: l.liveLabel,
                count: capacitiesAsync.maybeWhen(
                  data: (v) => v.where((c) => c.isLive).length,
                  orElse: () => 0,
                ),
                isActive: _liveFilter,
                color: AppColors.live,
                onTap: () => _setFilter(() { _typeFilter = null; _liveFilter = true; }),
              ),
            ],
            ),
          ),
        ),

        // ── SEARCH + FILTERS ──────────────────────────
        Container(
          color: c.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: TextStyle(color: c.textPrimary, fontSize: 15),
                onChanged: (v) => _setFilter(() => _searchText = v),
                decoration: InputDecoration(
                  hintText: l.feedSearchHint,
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _setFilter(() => _searchText = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _PillToggle(
                      label: l.sortNearestFirst,
                      icon: Icons.location_on_outlined,
                      isActive: _sortByProximity,
                      onTap: () => _setFilter(() => _sortByProximity = !_sortByProximity),
                    ),
                    const SizedBox(width: 8),
                    _PillDropdown(
                      icon: Icons.schedule_outlined,
                      label: _selectedWhen == 'Alle' ? l.whenLabel : _selectedWhen,
                      options: const ['Alle', 'NOW', 'WEEK', 'NEXT'],
                      labels: [l.whenAllTimes, l.whenNow, l.whenThisWeek, l.whenNextWeek],
                      selected: _selectedWhen,
                      onChanged: (v) => _setFilter(() => _selectedWhen = v),
                    ),
                    const SizedBox(width: 8),
                    _PillDropdown(
                      icon: Icons.groups_outlined,
                      label: _selectedCrew == 'Alle'
                          ? l.crewLabel
                          : '${_selectedCrew}+',
                      options: const ['Alle', '1', '3', '5', '10'],
                      labels: [l.crewAny, l.crew1plus, l.crew3plus, l.crew5plus, l.crew10plus],
                      selected: _selectedCrew,
                      onChanged: (v) => _setFilter(() => _selectedCrew = v),
                    ),
                    const SizedBox(width: 8),
                    TradePillDropdown(
                      selected: _selectedTrades,
                      onChanged: (v) => _setFilter(() => _selectedTrades = v),
                    ),
                    const SizedBox(width: 8),
                    _PillToggle(
                      label: l.saveSearchLabel,
                      icon: Icons.bookmark_add_outlined,
                      isActive: false,
                      onTap: _saveCurrentSearch,
                    ),
                  ],
                ),
              ),
              // Saved searches — one-tap re-filter (the retention seed).
              _SavedSearchesRow(onApply: _applySearch),
            ],
          ),
        ),

        // ── FEED ──────────────────────────────────────
        Expanded(
          child: capacitiesAsync.when(
            data: (capacities) {
              final filtered = _filterAndSort(capacities, l);

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.inbox_outlined, size: 40, color: AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.feedEmptyTitle,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l.feedEmptySubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: c.textTertiary, height: 1.5),
                      ),
                    ],
                  ),
                );
              }

              final hasMore = _visibleCount < filtered.length;
              final visible = filtered.take(_visibleCount).toList();

              return Stack(
                children: [
                  // Dot grid background
                  Positioned.fill(
                    child: CustomPaint(painter: DotGridPainter(color: c.textPrimary)),
                  ),
                  // Feed list — full-width so scroll works anywhere; constraint lives on each item
                  RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.refresh(capacitiesProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 80),
                      itemCount: visible.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visible.length) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 920),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                                child: _LoadMoreButton(
                                  onTap: () => setState(() => _visibleCount += _pageSize),
                                ),
                              ),
                            ),
                          );
                        }
                        final cap = visible[index];
                        Widget card = _LiveCapacityCard(
                          capacity: cap,
                          userPostalCode: widget.userPostalCode,
                          matchesProfile: viewerTrades.contains(cap.trade),
                        );
                        // Fade + rise once per card id (Set.add is true only the
                        // first time) — new posts feel alive, scroll stays calm.
                        if (_entryAnimated.add(cap.id)) card = EntryFade(child: card);
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                              child: card,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Bottom gradient fade (matches landing page language)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              c.background.withOpacity(0),
                              c.background.withOpacity(0.95),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const FeedSkeleton(),
            error: (e, _) => AppErrorState(
              error: e,
              onRetry: () => ref.refresh(capacitiesProvider),
            ),
          ),
        ),
      ],
    );
  }
}


// ─── TYPE TAB ───────────────────────────────────────

class _TypeTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.count,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 18, vertical: isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: isActive
              ? Border(bottom: BorderSide(color: color, width: 3))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
                color: isActive ? color : c.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: isMobile ? 5 : 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 7, vertical: isMobile ? 2 : 3),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.25) : c.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : c.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PILL TOGGLE ────────────────────────────────────

class _PillToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _PillToggle({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : c.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.primary : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? Colors.white : c.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PILL DROPDOWN ──────────────────────────────────

class _PillDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> options;
  final List<String> labels;
  final String selected;
  final Function(String) onChanged;

  const _PillDropdown({
    required this.label,
    required this.icon,
    required this.options,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isActive = selected != 'Alle';
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: c.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(options.length, (i) => ListTile(
                        title: Text(labels[i], style: TextStyle(color: c.textPrimary, fontSize: 16)),
                        trailing: selected == options[i]
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () {
                          onChanged(options[i]);
                          Navigator.pop(ctx);
                        },
                      )),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withOpacity(0.15) : c.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.primary : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? AppColors.primary : c.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.primary : c.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 15, color: isActive ? AppColors.primary : c.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── LIVE CAPACITY CARD ─────────────────────────────

class _LiveCapacityCard extends ConsumerWidget {
  final CapacityModel capacity;
  final String? userPostalCode;
  final bool matchesProfile;

  const _LiveCapacityCard({required this.capacity, this.userPostalCode, this.matchesProfile = false});

  void _openDetail(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l = AppLocalizations.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l.closeLabel,
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return Align(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width < 600 ? 0 : 40,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width < 600 ? size.width : 720,
                maxHeight: size.height * 0.88,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CapacityDetailScreen(capacity: capacity),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showShareSheet(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final shareUrl = 'https://capacify-mvp.web.app/?capacity=${capacity.id}';
    final text =
        '${capacity.typeLabel(l)}: ${capacity.autoTitle(l)}\n'
        '📍 ${capacity.location} · ${capacity.availabilityLabel(l)}\n'
        '👥 ${capacity.workerCount} ${l.persons} · ${l.tradeName(capacity.trade)}\n\n'
        '${l.shareFoundOnCapacify}\n$shareUrl';

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.shareSheetTitle,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              capacity.autoTitle(l),
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareButton(
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  icon: Icons.message_outlined,
                  onTap: () async {
                    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
                    try { await launchUrl(url); } catch (_) {}
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                _ShareButton(
                  label: 'LinkedIn',
                  color: const Color(0xFF0A66C2),
                  icon: Icons.work_outline,
                  onTap: () async {
                    // LinkedIn retired the old shareArticle?title=/summary=
                    // params years ago (anti-spam) — the current endpoint only
                    // takes a url and derives the preview from that page's own
                    // Open Graph tags.
                    final url = Uri.parse('https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(shareUrl)}');
                    try { await launchUrl(url); } catch (_) {}
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                _ShareButton(
                  label: l.shareCopy,
                  color: AppColors.primary,
                  icon: Icons.copy_outlined,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.shareCopiedSnackbar),
                          backgroundColor: AppColors.live,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // The gated step — opens the "Interesse senden" confirmation modal, which
  // creates a contact request. No contact/identity is ever revealed here.
  Future<void> _sendInterest(BuildContext context, WidgetRef ref) =>
      showInterestModal(context: context, ref: ref, capacity: capacity);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isOffer = capacity.type == CapacityType.offer;
    final accentColor = isOffer ? AppColors.offerColor : AppColors.needColor;

    double? distance;
    if (userPostalCode != null) {
      final d = LocationService.estimateDistanceFromPostalCode(userPostalCode!, capacity.location);
      if (d < 100) distance = d;
    }

    final isViewed = _viewedPosts.contains(capacity.id);

    final favoriteIds = ref.watch(userFavoriteIdsProvider).maybeWhen(
      data: (ids) => ids,
      orElse: () => <String>{},
    );
    final isFavorited = favoriteIds.contains(capacity.id);

    // The feed is anonymous, so a card can't (cheaply) tell whose post it is —
    // owners manage their own posts from My Listings, not the feed. Every card
    // offers "Kontakt anfragen"; requesting your own post is harmless (the
    // founder simply ignores it).
    const isOwner = false;

    // Availability colour coding: green = sofort, yellow = ab Datum
    // (this/next week), blue = nach Projektende (custom start).
    Color availabilityColor;
    switch (capacity.availabilityType) {
      case AvailabilityType.now:
        availabilityColor = AppColors.live;
        break;
      case AvailabilityType.thisWeek:
      case AvailabilityType.nextWeek:
        availabilityColor = AppColors.accent;
        break;
      case AvailabilityType.custom:
        availabilityColor = AppColors.distance;
        break;
    }

    return HoverLift(
      onTap: () {
        _viewedPosts.add(capacity.id);
        _openDetail(context);
      },
      builder: (context, hovered) {
        return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isViewed ? c.surface.withOpacity(0.75) : c.surface,
          borderRadius: BorderRadius.circular(12),
          // Border + shadow intensify on hover — the card reads as selectable.
          border: Border.all(
            color: hovered ? accentColor.withOpacity(0.55) : c.border,
            width: 1.5,
          ),
          boxShadow: hovered
              ? [BoxShadow(color: accentColor.withOpacity(0.16), blurRadius: 22, spreadRadius: 0, offset: const Offset(0, 6))]
              : (capacity.isLive
                  ? [BoxShadow(color: accentColor.withOpacity(0.10), blurRadius: 14, spreadRadius: 0)]
                  : null),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full-height left color strip
                Container(width: 4, color: accentColor),

                // Card content
                Expanded(
                  child: Column(
                    children: [
                      // ── Body ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: status badges (wrap — never overflow on
                            // mobile) + a meta line below (distance/freshness).
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Type badge — the one badge that keeps full
                                // color (offer/need is the core signal) and
                                // brightens slightly on card hover.
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(hovered ? 0.24 : 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: accentColor.withOpacity(hovered ? 0.75 : 0.5), width: 1.2),
                                  ),
                                  child: Text(
                                    capacity.typeLabel(l),
                                    style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                                  ),
                                ),
                                // Relevance — this post is in a trade the viewer
                                // works. Neutral tone: informational, not urgent.
                                if (matchesProfile)
                                  _FeedBadge(
                                    label: l.matchesProfileBadge,
                                    icon: Icons.person_pin_circle_outlined,
                                    color: AppColors.primary,
                                    filled: false,
                                  ),
                                // LIVE keeps color — real-time activity is the
                                // single most important freshness signal.
                                if (capacity.isLive)
                                  _FeedBadge(label: l.liveLabel, icon: Icons.circle, iconSize: 7, color: AppColors.live)
                                else if (capacity.isNew)
                                  _FeedBadge(label: l.newBadge, color: AppColors.accent, filled: false),
                                if (capacity.isInProgress)
                                  _FeedBadge(label: capacity.statusLabel(l), color: AppColors.distance, filled: false),
                                // Perishability — red only once truly urgent
                                // (≤2 days); otherwise a neutral countdown.
                                if (capacity.daysLeft != null && capacity.daysLeft! <= 7)
                                  _FeedBadge(
                                    label: l.daysLeftLabel(capacity.daysLeft!),
                                    icon: Icons.timelapse_outlined,
                                    color: AppColors.urgent,
                                    filled: capacity.daysLeft! <= 2,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Meta line: distance / freshness / seen.
                            Row(
                              children: [
                                if (distance != null) ...[
                                  Text(
                                    '${distance.round()} km',
                                    style: const TextStyle(color: AppColors.distance, fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                // "Heute bestätigt" beats "aktualisiert" — it's
                                // the poster actively vouching the crew is free.
                                if (capacity.confirmedToday) ...[
                                  const Icon(Icons.verified_outlined, size: 13, color: AppColors.live),
                                  const SizedBox(width: 3),
                                  Text(l.confirmedTodayLabel,
                                      style: const TextStyle(color: AppColors.live, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                ] else
                                  Text(
                                    capacity.timePostedLabel(l),
                                    style: TextStyle(color: c.textTertiary, fontSize: 12.5),
                                  ),
                                if (isViewed) ...[
                                  const SizedBox(width: 6),
                                  Text(l.seenLabel, style: TextStyle(color: c.textTertiary, fontSize: 10)),
                                ],
                              ],
                            ),

                            const SizedBox(height: 8),

                            // No company name, rating, or verified badge — the
                            // post is anonymous. Identity is only revealed
                            // through a granted contact request.

                            // Title — trade-led, biggest and boldest
                            Text(
                              capacity.autoTitle(l),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: c.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // Trust line — aggregate, non-identifying (no name):
                            // ✓ Verifiziert · ⭐ rating. The at-a-glance trust
                            // signal, shown only when the poster actually has it.
                            // (Subtitle removed — crew·district is already in the
                            // spec chips below; no duplication.)
                            if (capacity.posterVerified || capacity.posterRatingCount > 0) ...[
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  if (capacity.posterVerified) ...[
                                    const Icon(Icons.verified, size: 14, color: AppColors.live),
                                    const SizedBox(width: 4),
                                    Text(l.verifiedTitleCase,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.live)),
                                  ],
                                  if (capacity.posterVerified && capacity.posterRatingCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(width: 3, height: 3, decoration: BoxDecoration(color: c.textTertiary, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                  ],
                                  if (capacity.posterRatingCount > 0) ...[
                                    const Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
                                    const SizedBox(width: 3),
                                    Text(capacity.posterRating.toStringAsFixed(1),
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.textPrimary)),
                                    const SizedBox(width: 3),
                                    Text('(${capacity.posterRatingCount})',
                                        style: TextStyle(fontSize: 12, color: c.textTertiary)),
                                  ],
                                ],
                              ),
                            ],

                            // Description — trimmed to one line (secondary info;
                            // the full text lives in the detail view).
                            if (capacity.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                capacity.description,
                                style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.45),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Info chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _InfoChip(icon: Icons.build_outlined, label: l.tradeName(capacity.trade), color: accentColor),
                                _InfoChip(icon: Icons.location_on_outlined, label: capacity.location, color: AppColors.distance),
                                _InfoChip(icon: Icons.people_outline, label: '${capacity.workerCount} ${l.persPeriod}', color: c.textSecondary),
                                _InfoChip(icon: Icons.schedule_outlined, label: capacity.availabilityLabel(l), color: availabilityColor),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Stats row
                            Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 15, color: c.textTertiary),
                                const SizedBox(width: 4),
                                Text('${capacity.viewCount}', style: TextStyle(fontSize: 13, color: c.textTertiary, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                Icon(
                                  isFavorited ? Icons.favorite : Icons.favorite_outline,
                                  size: 15,
                                  color: isFavorited ? AppColors.primary : c.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text('${capacity.favoriteCount}', style: TextStyle(fontSize: 13, color: c.textTertiary, fontWeight: FontWeight.w600)),
                                // Social proof — real interest count (Objective 6),
                                // aggregate + non-identifying. Only when > 0.
                                if (capacity.interestCount > 0) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.handshake_outlined, size: 15, color: AppColors.live),
                                  const SizedBox(width: 4),
                                  Text(l.interestedCountLabel(capacity.interestCount),
                                      style: const TextStyle(fontSize: 13, color: AppColors.live, fontWeight: FontWeight.w700)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── Action bar ──
                      Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: c.border, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            // Interesse senden — the single gated action
                            if (!isOwner && !capacity.isClosed && !capacity.isCancelled)
                              Expanded(
                                child: PressableButton(
                                  onTap: () => _sendInterest(context, ref),
                                  builder: (context, hov, pressed) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    color: accentColor.withOpacity(hov ? 0.14 : 0.06),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.handshake_outlined, size: 16, color: accentColor),
                                        const SizedBox(width: 7),
                                        Text(
                                          l.sendInterestButton,
                                          style: TextStyle(fontSize: 13, color: accentColor, fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Spacer(),

                            // Separator
                            Container(width: 1, height: 32, color: c.border),

                            // Favorite
                            IconButton(
                              onPressed: () async {
                                final user = ref.read(authStateProvider).value;
                                if (user != null) {
                                  await ref.read(capacityServiceProvider).toggleFavorite(
                                    capacityId: capacity.id,
                                    userId: user.uid,
                                  );
                                }
                              },
                              icon: Icon(
                                isFavorited ? Icons.favorite : Icons.favorite_outline,
                                color: isFavorited ? AppColors.primary : c.textSecondary,
                                size: 20,
                              ),
                              tooltip: isFavorited ? l.removeFavoriteTooltip : l.addFavoriteTooltip,
                            ),

                            Container(width: 1, height: 32, color: c.border),

                            // Share
                            IconButton(
                              onPressed: () => _showShareSheet(context),
                              icon: Icon(Icons.share_outlined, color: c.textSecondary, size: 20),
                              tooltip: l.shareTooltip,
                            ),

                            Container(width: 1, height: 32, color: c.border),

                            // Report
                            if (!isOwner)
                              IconButton(
                                onPressed: () => _showReportDialog(context, ref, capacity),
                                icon: Icon(Icons.flag_outlined, color: c.textTertiary, size: 20),
                                tooltip: l.reportTooltip,
                              ),

                            if (!isOwner)
                              Container(width: 1, height: 32, color: c.border),

                            // Open detail popup
                            IconButton(
                              onPressed: () {
                                _viewedPosts.add(capacity.id);
                                _openDetail(context);
                              },
                              icon: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: accentColor),
                              tooltip: l.detailsTooltip,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

// ─── INFO CHIP ──────────────────────────────────────

// ─── STATUS BADGE (standardized size, reduced color palette) ────────────────
//
// One shared spec for every status badge in the card's top row (type, match,
// live/new, in-progress, perishability). `filled: true` reserves actual color
// for the handful of signals that matter most (offer/need, LIVE, ≤2-days-left
// urgency); everything else renders as a neutral, same-sized badge — so the
// card reads calmer without losing information.
class _FeedBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final double iconSize;
  final Color color;
  final bool filled;

  const _FeedBadge({
    required this.label,
    this.icon,
    this.iconSize = 11,
    required this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = filled ? color : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.15) : c.surfaceVariant,
        borderRadius: BorderRadius.circular(5),
        border: filled ? Border.all(color: color.withOpacity(0.5), width: 1.2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    // The 4 spec chips (Trade · Team · Location · Availability) are the card's
    // primary scan row — sized a touch larger/stronger than metadata.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13.5, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ─── SHARE BUTTON ───────────────────────────────────

class _ShareButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ShareButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Center(child: Icon(icon, color: color, size: 24)),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    );
  }
}

// ─── REPORT DIALOG ──────────────────────────────────

void _showReportDialog(BuildContext context, WidgetRef ref, CapacityModel capacity) {
  final user = ref.read(authStateProvider).value;
  if (user == null) return;

  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (ctx) {
      ReportReason? selected;
      bool isSubmitting = false;

      return StatefulBuilder(
        builder: (ctx, setState) {
          final c = AppColors.of(ctx);
          final l = AppLocalizations.of(ctx);
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.flag_outlined, color: AppColors.error, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.reportTitle2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.textPrimary)),
                              const SizedBox(height: 2),
                              Text(l.reportSubtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: c.border),
                    ...ReportReason.values.map((reason) => RadioListTile<ReportReason>(
                      value: reason,
                      groupValue: selected,
                      onChanged: (v) => setState(() => selected = v),
                      title: Text(l.reasonLabel(reason), style: TextStyle(fontSize: 14, color: c.textPrimary)),
                      activeColor: AppColors.primary,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    )),
                    Divider(height: 1, color: c.border),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.cancel))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.error.withOpacity(0.3),
                              ),
                              onPressed: selected == null || isSubmitting ? null : () async {
                                setState(() => isSubmitting = true);
                                try {
                                  await ref.read(reportServiceProvider).submitReport(
                                    capacityId: capacity.id,
                                    capacityTitle: capacity.autoTitle(l),
                                    // Post is anonymous — the reporter doesn't
                                    // know the company; admin resolves it from
                                    // capacityOwners via capacityId.
                                    companyId: '',
                                    companyName: '',
                                    reporterId: user.uid,
                                    reason: selected!,
                                  );
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l.reportSuccess), backgroundColor: AppColors.live),
                                    );
                                  }
                                } catch (_) {
                                  setState(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(l.reportError2), backgroundColor: AppColors.error),
                                    );
                                  }
                                }
                              },
                              child: isSubmitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(l.reportSubmit, style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ─── SAVED SEARCHES ROW ─────────────────────────────

class _SavedSearchesRow extends ConsumerWidget {
  final void Function(SavedSearchModel) onApply;
  const _SavedSearchesRow({required this.onApply});

  String _label(SavedSearchModel s, AppLocalizations l) {
    final parts = <String>[];
    parts.add(s.trades.isNotEmpty
        ? s.trades.map((t) => l.tradeName(t)).join(', ')
        : l.savedAnyTradesLabel);
    if (s.crewMin > 0) parts.add('${s.crewMin}+');
    if (s.when != 'Alle') parts.add(s.when);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final searches = ref.watch(mySavedSearchesProvider).valueOrNull ?? const [];
    if (searches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Icon(Icons.bookmark_outline, size: 15, color: c.textTertiary),
          const SizedBox(width: 8),
          for (final s in searches) ...[
            _SavedChip(
              label: _label(s, l),
              onApply: () => onApply(s),
              onDelete: () => ref.read(savedSearchServiceProvider).delete(s.id),
            ),
            const SizedBox(width: 6),
          ],
        ]),
      ),
    );
  }
}

class _SavedChip extends StatelessWidget {
  final String label;
  final VoidCallback onApply;
  final VoidCallback onDelete;
  const _SavedChip({required this.label, required this.onApply, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onApply,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(12),
            child: Icon(Icons.close, size: 14, color: c.textTertiary),
          ),
        ]),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textSecondary,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        label: Text(l.loadMoreButton, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
