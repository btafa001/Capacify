import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/report_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/star_rating.dart';
import 'capacity_detail_screen.dart';

final _viewedPosts = <String>{};

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

  String _selectedTrade = 'Alle';
  String _selectedWhen = 'Alle';
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

  List<CapacityModel> _filterAndSort(List<CapacityModel> capacities, AppLocalizations l) {
    var filtered = capacities.where((c) {
      if (_liveFilter && !c.isLive) return false;
      if (_typeFilter != null && c.type != _typeFilter) return false;
      if (_selectedTrade != 'Alle' && c.trade != _selectedTrade) return false;
      if (_selectedWhen == 'NOW' && c.availabilityType != AvailabilityType.now) return false;
      if (_selectedWhen == 'WEEK' && c.availabilityType != AvailabilityType.thisWeek) return false;
      if (_selectedWhen == 'NEXT' && c.availabilityType != AvailabilityType.nextWeek) return false;
      if (_searchText.isNotEmpty) {
        final q = _searchText.toLowerCase();
        return c.title.toLowerCase().contains(q) ||
            c.companyName.toLowerCase().contains(q) ||
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

    return Column(
      children: [
        // ── TYPE TABS ──────────────────────────────────
        Container(
          color: c.surface,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              _TypeTab(
                label: l.tabAll,
                count: capacitiesAsync.maybeWhen(data: (v) => v.length, orElse: () => 0),
                isActive: _typeFilter == null && !_liveFilter,
                color: c.textPrimary,
                onTap: () => _setFilter(() { _typeFilter = null; _liveFilter = false; }),
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
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
                      icon: Icons.build_outlined,
                      label: _selectedTrade == 'Alle' ? l.tradeFilterLabel : l.tradeName(_selectedTrade),
                      options: const [
                        'Alle', 'Rohbau', 'Trockenbau', 'Elektro', 'Sanitär & Heizung',
                        'Dach', 'Fassade', 'Tiefbau', 'Stahl', 'Beton', 'HVAC', 'Lieferant',
                      ],
                      labels: [
                        l.tradeAll, l.tradeName('Rohbau'), l.tradeName('Trockenbau'), l.tradeName('Elektro'), l.tradeName('Sanitär & Heizung'),
                        l.tradeName('Dach'), l.tradeName('Fassade'), l.tradeName('Tiefbau'), l.tradeName('Stahl'), l.tradeName('Beton'), l.tradeName('HVAC'), l.tradeName('Lieferant'),
                      ],
                      selected: _selectedTrade,
                      onChanged: (v) => _setFilter(() => _selectedTrade = v),
                    ),
                  ],
                ),
              ),
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
                    child: CustomPaint(painter: _FeedDotGrid()),
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
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                              child: _LiveCapacityCard(
                                capacity: visible[index],
                                userPostalCode: widget.userPostalCode,
                              ),
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
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Text(l.errorWithMessage(e), style: const TextStyle(color: AppColors.error)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── DOT GRID BACKGROUND ────────────────────────────

class _FeedDotGrid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..strokeCap = StrokeCap.round;
    const spacing = 28.0;
    const radius = 2.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
                color: isActive ? color : c.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.25) : c.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),
              ...List.generate(options.length, (i) => ListTile(
                title: Text(labels[i], style: TextStyle(color: c.textPrimary, fontSize: 16)),
                trailing: selected == options[i]
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  onChanged(options[i]);
                  Navigator.pop(ctx);
                },
              )),
              const SizedBox(height: 16),
            ],
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

  const _LiveCapacityCard({required this.capacity, this.userPostalCode});

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
    final text =
        '${capacity.typeLabel(l)}: ${capacity.autoTitle(l)}\n'
        '📍 ${capacity.location} · ${capacity.availabilityLabel(l)}\n'
        '👥 ${capacity.workerCount} ${l.persons} · ${l.tradeName(capacity.trade)}\n\n'
        '${l.shareFoundOnCapacify}\nhttps://capacify.de';

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
                    final url = Uri.parse('https://www.linkedin.com/shareArticle?mini=true&url=${Uri.encodeComponent('https://capacify.de')}&title=${Uri.encodeComponent(capacity.autoTitle(l))}');
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

  Future<void> _showInterest(BuildContext context) async {
    final l = AppLocalizations.of(context);
    if (capacity.companyEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.noContactDataSnackbar),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: capacity.companyEmail,
      queryParameters: {
        'subject': l.interestEmailSubject(capacity.autoTitle(l)),
        'body': l.interestEmailBody(capacity.autoTitle(l)),
      },
    );
    try {
      await launchUrl(uri);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.mailAppError),
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

    final currentUserId = ref.watch(authStateProvider).maybeWhen(
      data: (u) => u?.uid,
      orElse: () => null,
    );
    final isOwner = currentUserId != null && currentUserId == capacity.companyId;

    Color availabilityColor;
    switch (capacity.availabilityType) {
      case AvailabilityType.now:
        availabilityColor = AppColors.live;
        break;
      case AvailabilityType.thisWeek:
        availabilityColor = AppColors.accent;
        break;
      default:
        availabilityColor = c.textSecondary;
        break;
    }

    return GestureDetector(
      onTap: () {
        _viewedPosts.add(capacity.id);
        _openDetail(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isViewed ? c.surface.withOpacity(0.75) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 1.5),
          boxShadow: capacity.isLive
              ? [BoxShadow(color: accentColor.withOpacity(0.10), blurRadius: 14, spreadRadius: 0)]
              : null,
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
                            // Top row: type badge + live/new + negotiation + distance + time
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
                                  ),
                                  child: Text(
                                    capacity.typeLabel(l),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // LIVE badge with glow
                                if (capacity.isLive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.live.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: AppColors.live, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(color: AppColors.live.withOpacity(0.3), blurRadius: 8),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.circle, size: 7, color: AppColors.live),
                                        SizedBox(width: 4),
                                        Text('LIVE', style: TextStyle(color: AppColors.live, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                      ],
                                    ),
                                  )
                                else if (capacity.isNew)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(l.newBadge, style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                  ),
                                if (capacity.isInProgress)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.distance.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        capacity.statusLabel(l),
                                        style: const TextStyle(color: AppColors.distance, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                if (distance != null) ...[
                                  Text(
                                    '${distance.round()} km',
                                    style: const TextStyle(color: AppColors.distance, fontSize: 14, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Text(
                                  capacity.timePostedLabel(l),
                                  style: TextStyle(color: c.textTertiary, fontSize: 14),
                                ),
                                if (isViewed) ...[
                                  const SizedBox(width: 6),
                                  Text(l.seenLabel, style: TextStyle(color: c.textTertiary, fontSize: 10)),
                                ],
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Company name + rating + optional verified badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    capacity.companyName,
                                    style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                CompanyRatingBadge(companyId: capacity.companyId),
                                if (capacity.companyVerified) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.live.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.live.withOpacity(0.30)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.verified, size: 11, color: AppColors.live),
                                        const SizedBox(width: 3),
                                        Text(l.verifiedLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.live, letterSpacing: 0.3)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Title — biggest and boldest
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

                            // Description snippet
                            if (capacity.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                capacity.description,
                                style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                                maxLines: 2,
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
                            // Interesse bekunden — primary CTA (non-owner, active only)
                            if (!isOwner && !capacity.isClosed && !capacity.isCancelled)
                              Expanded(
                                child: Material(
                                  color: accentColor.withOpacity(0.06),
                                  child: InkWell(
                                    onTap: () => _showInterest(context),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.handshake_outlined, size: 16, color: accentColor),
                                          const SizedBox(width: 7),
                                          Text(
                                            l.expressInterest,
                                            style: TextStyle(fontSize: 13, color: accentColor, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
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
      ),
    );
  }
}

// ─── INFO CHIP ──────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
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
                                    companyId: capacity.companyId,
                                    companyName: capacity.companyName,
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
