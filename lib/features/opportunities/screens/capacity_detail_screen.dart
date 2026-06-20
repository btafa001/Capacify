import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/star_rating.dart';

class CapacityDetailScreen extends ConsumerStatefulWidget {
  final CapacityModel capacity;

  const CapacityDetailScreen({
    super.key,
    required this.capacity,
  });

  @override
  ConsumerState<CapacityDetailScreen> createState() =>
      _CapacityDetailScreenState();
}

class _CapacityDetailScreenState
    extends ConsumerState<CapacityDetailScreen> {
  bool _isFavorited = false;
  bool _loadingFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(capacityServiceProvider)
          .incrementViewCount(widget.capacity.id);
    });
  }

  Future<void> _loadFavoriteState() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final isFav = await ref
        .read(capacityServiceProvider)
        .isFavorited(
          capacityId: widget.capacity.id,
          userId: user.uid,
        );
    if (mounted) setState(() => _isFavorited = isFav);
  }

  Future<void> _toggleFavorite() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _loadingFavorite = true);
    final result = await ref
        .read(capacityServiceProvider)
        .toggleFavorite(
          capacityId: widget.capacity.id,
          userId: user.uid,
        );
    if (mounted) {
      setState(() {
        _isFavorited = result;
        _loadingFavorite = false;
      });
    }
  }

  Future<void> _launchPhone() async {
    final l = AppLocalizations.of(context);
    if (widget.capacity.companyPhone.isEmpty) {
      _showSnackbar(l.noPhoneSnackbar, AppColors.error);
      return;
    }
    final url = Uri.parse('tel:${widget.capacity.companyPhone}');
    try {
      await launchUrl(url);
    } catch (_) {
      _showSnackbar(l.callFailedSnackbar, AppColors.error);
    }
  }

  Future<void> _launchEmail() async {
    final l = AppLocalizations.of(context);
    if (widget.capacity.companyEmail.isEmpty) {
      _showSnackbar(l.noEmailSnackbar, AppColors.error);
      return;
    }
    final url = Uri.parse('mailto:${widget.capacity.companyEmail}');
    try {
      await launchUrl(url);
    } catch (_) {
      _showSnackbar(l.mailAppError, AppColors.error);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackbar(AppLocalizations.of(context).copiedSuffix(label), AppColors.live);
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateStatus(
    CapacityStatus newStatus,
  ) async {
    final l = AppLocalizations.of(context);
    String title;
    String body;
    String confirmLabel;
    Color confirmColor;

    switch (newStatus) {
      case CapacityStatus.active:
        title = l.confirmBackToActiveTitle;
        body = l.confirmBackToActiveBody(widget.capacity.autoTitle(l));
        confirmLabel = l.confirmGenericLabel;
        confirmColor = AppColors.live;
        break;
      case CapacityStatus.closed:
        title = l.confirmAwardTitle;
        body = l.confirmCloseBody(widget.capacity.autoTitle(l));
        confirmLabel = l.confirmAwardCheckLabel;
        confirmColor = AppColors.live;
        break;
      case CapacityStatus.inProgress:
        title = l.confirmNegotiationTitle;
        body = l.negotiationStaysVisibleBody;
        confirmLabel = l.confirmGenericLabel;
        confirmColor = AppColors.distance;
        break;
      case CapacityStatus.cancelled:
        title = l.confirmCancelTitle;
        body = l.confirmCancelBody(widget.capacity.autoTitle(l));
        confirmLabel = l.cancelActionLabel;
        confirmColor = AppColors.error;
        break;
      default:
        return;
    }

    final c = AppColors.of(context);
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
          .updateStatus(widget.capacity.id, newStatus);

      if (mounted) {
        _showSnackbar(
          newStatus == CapacityStatus.closed
              ? l.confirmAwardCheckLabel
              : newStatus == CapacityStatus.inProgress
                  ? l.statusNegotiationSnackbar
                  : newStatus == CapacityStatus.active
                      ? l.statusActiveSnackbar
                      : l.postingCancelledSnackbar,
          confirmColor,
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final capacity = widget.capacity;
    final isOffer = capacity.type == CapacityType.offer;
    final accentColor = isOffer
        ? AppColors.offerColor
        : AppColors.needColor;

    // Owner detection
    final currentUserId =
        FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null &&
        currentUserId == capacity.companyId;

    // Status color
    final statusColor = _resolveStatusColor(
      capacity.status,
      accentColor,
    );

    final c = AppColors.of(context);
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
        title: Text(
          capacity.typeLabel(l),
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        actions: [
          if (!capacity.isClosed &&
              !capacity.isCancelled)
            IconButton(
              icon: _loadingFavorite
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      _isFavorited
                          ? Icons.favorite
                          : Icons.favorite_outline,
                      color: _isFavorited
                          ? AppColors.primary
                          : c.textSecondary,
                    ),
              onPressed: _toggleFavorite,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ── BADGES ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailBadge(
                        label: capacity.typeLabel(l),
                        color: accentColor,
                        filled: true,
                      ),
                      if (!capacity.isActive)
                        _DetailBadge(
                          label: capacity.statusLabel(l),
                          color: statusColor,
                          filled: false,
                        ),
                      if (capacity.isLive)
                        _LiveBadgeWidget(),
                      if (capacity.isNew &&
                          !capacity.isLive)
                        _DetailBadge(
                          label: l.newBadge,
                          color: AppColors.accent,
                          filled: false,
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── TITLE ──
                  Text(
                    capacity.autoTitle(l),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: c.textPrimary,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Text(
                        capacity.companyName,
                        style: TextStyle(
                          fontSize: 16,
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CompanyRatingBadge(companyId: capacity.companyId, starSize: 14, fontSize: 13),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── INFO GRID ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                          color: c.border),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon:
                              Icons.location_on_outlined,
                          label: l.locationLabel,
                          value: capacity.location,
                          color: AppColors.distance,
                        ),
                        _Divider(),
                        _InfoRow(
                          icon: Icons.people_outline,
                          label: l.persons,
                          value:
                              '${capacity.workerCount} ${l.persons}',
                          color: accentColor,
                        ),
                        _Divider(),
                        _InfoRow(
                          icon: Icons.build_outlined,
                          label: l.tradeFilterLabel,
                          value: l.tradeName(capacity.trade),
                          color: accentColor,
                        ),
                        _Divider(),
                        _InfoRow(
                          icon: Icons.schedule_outlined,
                          label: l.availabilityLabelText,
                          value:
                              capacity.availabilityLabel(l),
                          color: AppColors.accent,
                        ),
                        if (capacity.closedAt !=
                            null) ...[
                          _Divider(),
                          _InfoRow(
                            icon: Icons
                                .check_circle_outline,
                            label: l.completedLabel,
                            value:
                                '${capacity.closedAt!.day}.${capacity.closedAt!.month}.${capacity.closedAt!.year}',
                            color: AppColors.live,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── DESCRIPTION ──
                  if (capacity.description
                      .isNotEmpty) ...[
                    Text(
                      l.descriptionLabel,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: c.border,
                        ),
                      ),
                      child: Text(
                        capacity.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: c.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── STATS ──
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _StatPill(
                        icon: Icons.visibility_outlined,
                        value: l.viewsCount(capacity.viewCount),
                        color: c.textTertiary,
                      ),
                      _StatPill(
                        icon: Icons.favorite_outline,
                        value: l.favoritesCount(capacity.favoriteCount),
                        color: c.textTertiary,
                      ),
                      if (capacity.interestCount > 0)
                        _StatPill(
                          icon: Icons.people_outline,
                          value: l.interestedCount(capacity.interestCount),
                          color: AppColors.primary,
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── CONTACT (non-owner, active posts) ──
                  if (!isOwner &&
                      !capacity.isClosed &&
                      !capacity.isCancelled) ...[
                    Text(
                      l.contactLabel,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: c.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (capacity
                              .companyPhone.isNotEmpty)
                            _ContactRow(
                              icon:
                                  Icons.phone_outlined,
                              value:
                                  capacity.companyPhone,
                              label: l.phoneLabel,
                              onTap: _launchPhone,
                              onCopy: () =>
                                  _copyToClipboard(
                                capacity.companyPhone,
                                l.phoneLabel,
                              ),
                              color: accentColor,
                            ),
                          if (capacity
                                  .companyPhone
                                  .isNotEmpty &&
                              capacity
                                  .companyEmail.isNotEmpty)
                            _Divider(),
                          if (capacity
                              .companyEmail.isNotEmpty)
                            _ContactRow(
                              icon: Icons.mail_outline,
                              value:
                                  capacity.companyEmail,
                              label: l.emailLabel,
                              onTap: _launchEmail,
                              onCopy: () =>
                                  _copyToClipboard(
                                capacity.companyEmail,
                                l.emailLabel,
                              ),
                              color: accentColor,
                            ),
                          if (capacity
                                  .companyPhone
                                  .isEmpty &&
                              capacity
                                  .companyEmail.isEmpty)
                            Text(
                              l.noContactInfoText,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── CLOSED INFO ──
                  if (capacity.isClosed) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.live
                            .withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.live
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.live,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.jobAwardedArchivedNotice,
                              style: const TextStyle(
                                color: AppColors.live,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (capacity.dealNumber != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.live.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l.dealNumberLabel(capacity.dealNumber!),
                                style: const TextStyle(
                                  color: AppColors.live,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── CANCELLED INFO ──
                  if (capacity.isCancelled) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error
                            .withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cancel_outlined,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.postingCancelledNotice,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Posted time
                  if (capacity.createdAt != null)
                    Text(
                      l.postedAt(capacity.timePostedLabel(l)),
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── BOTTOM ACTIONS ──
          _BottomActions(
            capacity: capacity,
            isOwner: isOwner,
            accentColor: accentColor,
            onPhone: _launchPhone,
            onEmail: _launchEmail,
            onUpdateStatus: _updateStatus,
          ),
        ],
      ),
    );
  }

  Color _resolveStatusColor(
    CapacityStatus status,
    Color fallback,
  ) {
    switch (status) {
      case CapacityStatus.inProgress:
        return AppColors.distance;
      case CapacityStatus.closed:
        return AppColors.live;
      case CapacityStatus.cancelled:
        return AppColors.error;
      default:
        return fallback;
    }
  }
}

// ─────────────────────────────────────────────────────
//  BOTTOM ACTIONS
// ─────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final CapacityModel capacity;
  final bool isOwner;
  final Color accentColor;
  final VoidCallback onPhone;
  final VoidCallback onEmail;
  final Function(CapacityStatus) onUpdateStatus;

  const _BottomActions({
    required this.capacity,
    required this.isOwner,
    required this.accentColor,
    required this.onPhone,
    required this.onEmail,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Archived — no actions
    if (capacity.isClosed || capacity.isCancelled) {
      return const SizedBox.shrink();
    }

    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    // Owner — lifecycle actions
    if (isOwner) {
      return Container(
        padding: const EdgeInsets.fromLTRB(
            16, 14, 16, 20),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            top: BorderSide(
              color: c.border,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            // Interest count row
            if (capacity.interestCount > 0)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.interestedCount(capacity.interestCount),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            // In Verhandlung (only if active)
            if (capacity.isActive) ...[
              OutlinedButton.icon(
                onPressed: () => onUpdateStatus(
                  CapacityStatus.inProgress,
                ),
                icon: const Icon(
                  Icons.handshake_outlined,
                  size: 18,
                ),
                label: Text(
                  l.setNegotiationButton,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.distance,
                  side: const BorderSide(
                    color: AppColors.distance,
                    width: 1.5,
                  ),
                  minimumSize:
                      const Size(double.infinity, 46),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Zurück auf Aktiv (only if in progress)
            if (capacity.isInProgress) ...[
              OutlinedButton.icon(
                onPressed: () => onUpdateStatus(
                  CapacityStatus.active,
                ),
                icon: const Icon(
                  Icons.undo_outlined,
                  size: 18,
                ),
                label: Text(
                  l.setActiveButton,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.live,
                  side: const BorderSide(
                    color: AppColors.live,
                    width: 1.5,
                  ),
                  minimumSize:
                      const Size(double.infinity, 46),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Auftrag vergeben — primary CTA
            ElevatedButton.icon(
              onPressed: () => onUpdateStatus(
                CapacityStatus.closed,
              ),
              icon: const Icon(
                Icons.check_circle_outline,
                size: 18,
              ),
              label: Text(
                l.awardJobButtonCaps,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.live,
                minimumSize:
                    const Size(double.infinity, 50),
                elevation: 4,
                shadowColor:
                    AppColors.live.withOpacity(0.3),
              ),
            ),

            const SizedBox(height: 6),

            // Stornieren — text only
            TextButton(
              onPressed: () => onUpdateStatus(
                CapacityStatus.cancelled,
              ),
              child: Text(
                l.cancelPostingButton,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Viewer — contact actions
    return Container(
      padding:
          const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(
            color: c.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onPhone,
              icon: const Icon(
                Icons.phone_outlined,
                size: 18,
              ),
              label: Text(
                l.callButton,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                minimumSize:
                    const Size(double.infinity, 48),
                elevation: 4,
                shadowColor:
                    accentColor.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEmail,
              icon: Icon(
                Icons.mail_outline,
                size: 18,
                color: accentColor,
              ),
              label: Text(
                l.emailLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: accentColor,
                  width: 1.5,
                ),
                minimumSize:
                    const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Divider(
      color: c.border,
      height: 20,
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _DetailBadge({
    required this.label,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: filled
            ? color.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LiveBadgeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.live.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.live,
          width: 1.5,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: AppColors.live,
          ),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.live,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Icon(icon, size: 17, color: color),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: c.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final Color color;

  const _ContactRow({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    required this.onCopy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Icon(icon, size: 17, color: color),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: c.textTertiary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.copy_outlined,
            size: 16,
            color: c.textTertiary,
          ),
          onPressed: onCopy,
          tooltip: l.copyTooltip(label),
        ),
        IconButton(
          icon: Icon(
            icon == Icons.phone_outlined
                ? Icons.phone
                : Icons.open_in_new,
            size: 16,
            color: color,
          ),
          onPressed: onTap,
          tooltip: label,
        ),
      ],
    );
  }
}