import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/localization/app_localizations.dart';
import 'create_capacity_screen.dart';
import 'capacity_detail_screen.dart';

class MyCapacitiesScreen extends ConsumerStatefulWidget {
  final CompanyModel company;

  const MyCapacitiesScreen({
    super.key,
    required this.company,
  });

  @override
  ConsumerState<MyCapacitiesScreen> createState() =>
      _MyCapacitiesScreenState();
}

class _MyCapacitiesScreenState
    extends ConsumerState<MyCapacitiesScreen> {
  String _filter = 'Aktiv';

  final _filters = [
    'Alle',
    'Aktiv',
    'In Verhandlung',
    'Vergeben',
    'Storniert',
  ];

  String _statusDisplayLabel(AppLocalizations l, CapacityStatus s) {
    switch (s) {
      case CapacityStatus.inProgress:
        return l.negotiationLabel;
      case CapacityStatus.closed:
        return l.statusAwardedTitle;
      case CapacityStatus.cancelled:
        return l.statusCancelledTitle;
      default:
        return l.statusActiveTitle;
    }
  }

  String _filterDisplayLabel(AppLocalizations l, String f) {
    switch (f) {
      case 'Aktiv':
        return l.statusActiveTitle;
      case 'In Verhandlung':
        return l.negotiationLabel;
      case 'Vergeben':
        return l.statusAwardedTitle;
      case 'Storniert':
        return l.statusCancelledTitle;
      default:
        return l.typeAll;
    }
  }

  List<CapacityModel> _applyFilter(
    List<CapacityModel> all,
  ) {
    switch (_filter) {
      case 'Aktiv':
        return all
            .where((c) => c.status == CapacityStatus.active)
            .toList();
      case 'In Verhandlung':
        return all
            .where(
              (c) => c.status == CapacityStatus.inProgress,
            )
            .toList();
      case 'Vergeben':
        return all
            .where((c) => c.status == CapacityStatus.closed)
            .toList();
      case 'Storniert':
        return all
            .where(
              (c) => c.status == CapacityStatus.cancelled,
            )
            .toList();
      default:
        return all;
    }
  }

  Future<void> _confirmStatusChange({
    required BuildContext context,
    required CapacityModel capacity,
    required CapacityStatus newStatus,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          title,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: Text(
          body,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(capacityServiceProvider)
          .updateStatus(capacity.id, newStatus);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l.statusUpdatedPrefix} ${_statusDisplayLabel(l, newStatus)}',
            ),
            backgroundColor: AppColors.live,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final postsAsync =
        ref.watch(myCapacitiesProvider(widget.company.id));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: c.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.myPostingsTitle,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              widget.company.name,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                final size = MediaQuery.of(context).size;
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
                            child: CreateCapacityScreen(company: widget.company),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              icon: const Icon(Icons.flash_on, size: 16),
              label: Text(l.newPostingButton),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 36),
              ),
            ),
          ),
        ],
      ),
      body: postsAsync.when(
        data: (allPosts) {
          // Stats
          final activeCount = allPosts
              .where(
                (cap) => cap.status == CapacityStatus.active,
              )
              .length;
          final inProgressCount = allPosts
              .where(
                (cap) =>
                    cap.status == CapacityStatus.inProgress,
              )
              .length;
          final closedCount = allPosts
              .where(
                (cap) => cap.status == CapacityStatus.closed,
              )
              .length;
          final cancelledCount = allPosts
              .where(
                (cap) =>
                    cap.status == CapacityStatus.cancelled,
              )
              .length;

          final filtered = _applyFilter(allPosts);

          return Column(
            children: [
              // Stats bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  border: Border(
                    bottom: BorderSide(
                      color: c.border,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _StatDot(
                      count: activeCount,
                      label: l.statusActiveTitle,
                      color: AppColors.live,
                    ),
                    const SizedBox(width: 16),
                    _StatDot(
                      count: inProgressCount,
                      label: l.negotiationShortLabel,
                      color: AppColors.distance,
                    ),
                    const SizedBox(width: 16),
                    _StatDot(
                      count: closedCount,
                      label: l.statusAwardedTitle,
                      color: AppColors.offerColor,
                    ),
                    const SizedBox(width: 16),
                    _StatDot(
                      count: cancelledCount,
                      label: l.statusCancelledTitle,
                      color: c.textTertiary,
                    ),
                    const Spacer(),
                    Text(
                      l.totalLabel(allPosts.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter chips
              Container(
                color: c.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final isActive = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(
                          right: 8,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _filter = f,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(
                              milliseconds: 180,
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                      .withOpacity(0.15)
                                  : c.surfaceVariant,
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.primary
                                    : c.border,
                              ),
                            ),
                            child: Text(
                              _filterDisplayLabel(l, f),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isActive
                                    ? AppColors.primary
                                    : c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 56,
                              color: c.textTertiary,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              l.noPostingsUnderFilter(_filterDisplayLabel(l, _filter)),
                              style: TextStyle(
                                fontSize: 15,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 16, bottom: 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 920),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: _MyPostingCard(
                                  capacity: filtered[index],
                                  onStatusChange: (newStatus) =>
                                      _confirmStatusChange(
                                    context: context,
                                    capacity: filtered[index],
                                    newStatus: newStatus,
                                    title: _statusChangeTitle(
                                      l, newStatus,
                                    ),
                                    body: _statusChangeBody(
                                      l, newStatus,
                                      filtered[index].title,
                                    ),
                                    confirmLabel:
                                        _statusConfirmLabel(
                                      l, newStatus,
                                    ),
                                    confirmColor:
                                        _statusConfirmColor(
                                      newStatus,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            l.errorWithMessage(e),
            style:
                const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  String _statusChangeTitle(AppLocalizations l, CapacityStatus s) {
    switch (s) {
      case CapacityStatus.closed:
        return l.confirmAwardTitle;
      case CapacityStatus.inProgress:
        return l.confirmNegotiationTitle;
      case CapacityStatus.cancelled:
        return l.confirmCancelTitle;
      default:
        return l.confirmStatusChangeTitle;
    }
  }

  String _statusChangeBody(
    AppLocalizations l,
    CapacityStatus s,
    String title,
  ) {
    switch (s) {
      case CapacityStatus.closed:
        return l.confirmAwardBody(title);
      case CapacityStatus.inProgress:
        return l.confirmNegotiationBody(title);
      case CapacityStatus.cancelled:
        return l.confirmCancelBody(title);
      default:
        return l.confirmStatusChangeTitle;
    }
  }

  String _statusConfirmLabel(AppLocalizations l, CapacityStatus s) {
    switch (s) {
      case CapacityStatus.closed:
        return l.statusAwardedTitle;
      case CapacityStatus.inProgress:
        return l.negotiationLabel;
      case CapacityStatus.cancelled:
        return l.cancelActionLabel;
      default:
        return l.confirmGenericLabel;
    }
  }

  Color _statusConfirmColor(CapacityStatus s) {
    switch (s) {
      case CapacityStatus.closed:
        return AppColors.live;
      case CapacityStatus.inProgress:
        return AppColors.distance;
      case CapacityStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}

// ─── Stat dot ───

class _StatDot extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatDot({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 12,
            color: c.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Card ───

class _MyPostingCard extends StatelessWidget {
  final CapacityModel capacity;
  final Function(CapacityStatus) onStatusChange;

  const _MyPostingCard({
    required this.capacity,
    required this.onStatusChange,
  });

  Color get _accentColor {
    return capacity.type == CapacityType.offer
        ? AppColors.offerColor
        : AppColors.needColor;
  }

  Color get _statusColor {
    switch (capacity.status) {
      case CapacityStatus.inProgress:
        return AppColors.distance;
      case CapacityStatus.closed:
        return AppColors.live;
      case CapacityStatus.cancelled:
        return Colors.grey;
      default:
        return _accentColor;
    }
  }

  bool get _isDimmed =>
      capacity.isClosed || capacity.isCancelled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CapacityDetailScreen(
              capacity: capacity,
            ),
          ),
        );
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isDimmed ? 0.55 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDimmed
                  ? c.border
                  : _accentColor.withOpacity(0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Status strip
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: _isDimmed
                      ? c.border
                      : _statusColor,
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Type badge
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor
                                .withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            capacity.type ==
                                    CapacityType.offer
                                ? l.offerLabel
                                : l.needLabel,
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 9,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Status badge
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor
                                .withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            capacity.statusLabel(l),
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: 9,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),

                        if (capacity.contentFlagged) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: AppColors.accent.withOpacity(0.35)),
                            ),
                            child: Text(
                              l.contentUnderReviewBadge,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),

                        Text(
                          capacity.timePostedLabel(l),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      capacity.autoTitle(l),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _isDimmed
                            ? c.textSecondary
                            : c.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          capacity.location,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.people_outline,
                          size: 12,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${capacity.workerCount} ${l.persPeriod}',
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                        if (capacity.interestCount > 0) ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.visibility_outlined,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            l.interestedCount(capacity.interestCount),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions menu — only for non-closed
              if (!capacity.isClosed &&
                  !capacity.isCancelled)
                PopupMenuButton<String>(
                  color: c.surface,
                  icon: Icon(
                    Icons.more_vert,
                    color: c.textSecondary,
                    size: 20,
                  ),
                  itemBuilder: (ctx) => [
                    // Only show "Auftrag vergeben" for active/inProgress
                    if (capacity.isActive ||
                        capacity.isInProgress)
                      PopupMenuItem(
                        value: 'close',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.live,
                              size: 17,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l.awardJobAction,
                              style: const TextStyle(
                                color: AppColors.live,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Only show "In Verhandlung" for active posts
                    if (capacity.isActive)
                      PopupMenuItem(
                        value: 'inProgress',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              color: AppColors.distance,
                              size: 17,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l.negotiationLabel,
                              style: const TextStyle(
                                color: AppColors.distance,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cancel_outlined,
                            color: AppColors.error,
                            size: 17,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l.cancelActionLabel,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'close':
                        onStatusChange(
                          CapacityStatus.closed,
                        );
                        break;
                      case 'inProgress':
                        onStatusChange(
                          CapacityStatus.inProgress,
                        );
                        break;
                      case 'cancel':
                        onStatusChange(
                          CapacityStatus.cancelled,
                        );
                        break;
                    }
                  },
                ),

              // Closed/cancelled indicator (no menu)
              if (capacity.isClosed ||
                  capacity.isCancelled)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.archive_outlined,
                    color: c.textTertiary,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}