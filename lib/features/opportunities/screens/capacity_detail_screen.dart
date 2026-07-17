import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/capacity_owner_model.dart';
import '../../../core/models/company_model.dart';
import '../../../shared/widgets/company_logo_avatar.dart';
import '../../../core/models/contact_request_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/contact_request_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import '../../company/screens/company_profile_screen.dart';
import '../../company/screens/company_detail_screen.dart';
import '../widgets/interest_modal.dart';

/// Opens a capacity's details as a compact popup instead of pushing a
/// full-screen route — used from My Listings and Favorites, where a quick
/// glance back at the list afterwards matters more than full-screen detail.
void showCapacityDetailDialog(BuildContext context, CapacityModel capacity) {
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
          constraints: BoxConstraints(maxWidth: size.width < 600 ? size.width : 560, maxHeight: size.height * 0.88),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CapacityDetailScreen(capacity: capacity)),
        ),
      ),
    ),
  );
}

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
  CompanyModel? _viewerCompany;
  // The locked identity sidecar — non-null ONLY if Firestore released it to
  // this viewer (owner, admin, or granted requester). null = anonymous.
  CapacityOwnerModel? _ownerDoc;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('CapacityDetail');
    _loadFavoriteState();
    _loadViewerCompany();
    _loadOwnerDoc();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(capacityServiceProvider)
          .incrementViewCount(widget.capacity.id);
    });
  }

  Future<void> _loadOwnerDoc() async {
    final owner =
        await ref.read(capacityServiceProvider).getCapacityOwner(widget.capacity.id);
    if (mounted) setState(() => _ownerDoc = owner);
  }

  Future<void> _loadViewerCompany() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final company = await ref.read(companyServiceProvider).getCompanyByOwner(user.uid);
    if (mounted) setState(() => _viewerCompany = company);
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
    final phone = _ownerDoc?.contactPhone ?? '';
    if (phone.isEmpty) {
      _showSnackbar(l.noPhoneSnackbar, AppColors.error);
      return;
    }
    final url = Uri.parse('tel:$phone');
    try {
      await launchUrl(url);
      AnalyticsService.logEvent('capacity_contact_click', parameters: {'method': 'phone', 'trade': widget.capacity.trade});
    } catch (_) {
      _showSnackbar(l.callFailedSnackbar, AppColors.error);
    }
  }

  Future<void> _launchEmail() async {
    final l = AppLocalizations.of(context);
    final email = _ownerDoc?.contactEmail ?? '';
    if (email.isEmpty) {
      _showSnackbar(l.noEmailSnackbar, AppColors.error);
      return;
    }
    final url = Uri.parse('mailto:$email');
    try {
      await launchUrl(url);
      AnalyticsService.logEvent('capacity_contact_click', parameters: {'method': 'email', 'trade': widget.capacity.trade});
    } catch (_) {
      _showSnackbar(l.mailAppError, AppColors.error);
    }
  }

  // ── The gated step — opens the "Interesse senden" confirmation modal. ──
  Future<void> _requestContact() =>
      showInterestModal(context: context, ref: ref, capacity: widget.capacity);

  Future<void> _setOutcome(ContactRequestModel req, String outcome) async {
    final l = AppLocalizations.of(context);
    try {
      await ref
          .read(contactRequestServiceProvider)
          .setOutcome(requestId: req.id, outcome: outcome);
      if (mounted) _showSnackbar(l.thanksForFeedbackSnackbar, AppColors.live);
    } catch (e) {
      if (mounted) _showSnackbar(l.errorWithMessage(e), AppColors.error);
    }
  }

  /// The entire contact area. States:
  ///   owner / closed / cancelled → nothing (handled elsewhere / bottom bar).
  ///   revealed (_ownerDoc released to owner, admin, or a granted requester) →
  ///     the identity: company name + contact + optional outcome feedback.
  ///   anonymous → the trust block (verification/rating/district/trade, NO
  ///     name) plus the request status if one exists.
  /// Identity only ever appears in the revealed branch, sourced from the
  /// rule-released _ownerDoc — never from the public post. The primary
  /// "Interesse senden" action lives in the sticky bottom bar.
  Widget _buildContactGate(AppLocalizations l, bool isOwner) {
    final capacity = widget.capacity;
    if (isOwner || capacity.isClosed || capacity.isCancelled) {
      return const SizedBox.shrink();
    }
    final c = AppColors.of(context);
    final accent = capacity.type == CapacityType.offer
        ? AppColors.offerColor
        : AppColors.needColor;

    // This viewer's request for this post (drives status + the granted reveal).
    final viewerId = _viewerCompany?.id;
    final req = viewerId == null
        ? null
        : ref
            .watch(myRequestForPostProvider(
                (requesterCompanyId: viewerId, postId: capacity.id)))
            .valueOrNull;

    // Once granted, fetch the now-readable owner doc so contact appears.
    if (req?.status == 'granted' && _ownerDoc == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwnerDoc());
    }

    // ── Revealed — identity + contact (only reachable post-accept/admin). ──
    if (_ownerDoc != null) {
      final name = _ownerDoc!.companyName;
      final phone = _ownerDoc!.contactPhone;
      final email = _ownerDoc!.contactEmail;
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.requestContactRevealedTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.textPrimary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.live.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.live.withOpacity(0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (name.isNotEmpty) ...[
                Row(children: [
                  const Icon(Icons.business_outlined, size: 18, color: AppColors.live),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary))),
                ]),
                const SizedBox(height: 12),
              ],
              if (phone.isNotEmpty)
                _ContactRow(icon: Icons.phone_outlined, value: phone, label: l.phoneLabel, onTap: _launchPhone, onCopy: () => _copyToClipboard(phone, l.phoneLabel), color: accent),
              if (phone.isNotEmpty && email.isNotEmpty) _Divider(),
              if (email.isNotEmpty)
                _ContactRow(icon: Icons.mail_outline, value: email, label: l.emailLabel, onTap: _launchEmail, onCopy: () => _copyToClipboard(email, l.emailLabel), color: accent),
              if (phone.isEmpty && email.isEmpty && name.isEmpty)
                Text(l.noContactInfoText, style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ]),
          ),
          if (req != null && req.outcome == null) ...[
            const SizedBox(height: 14),
            _buildOutcomePrompt(l, c, req),
          ],
        ]),
      );
    }

    // ── Anonymous — trust signals (no identity) + request status. ──
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildTrustBlock(l, c),
        if (req != null && req.status != 'granted') ...[
          const SizedBox(height: 14),
          _buildRequestStatus(l, c, req),
        ],
      ]),
    );
  }

  /// Trust WITHOUT identity — verification, aggregate rating, district, and
  /// trade/crew, all read from the public post. Builds confidence but names no
  /// one; the company name is revealed only after the poster accepts (note).
  Widget _buildTrustBlock(AppLocalizations l, dynamic c) {
    final capacity = widget.capacity;
    final ratingText = capacity.posterRatingCount > 0
        ? l.trustRatingSummary(
            capacity.posterRating.toStringAsFixed(1), capacity.posterRatingCount)
        : l.trustNoRatingsYet;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.trustBlockTitle,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.textPrimary)),
        const SizedBox(height: 12),
        _TrustRow(
          icon: capacity.posterVerified ? Icons.verified_outlined : Icons.shield_outlined,
          color: capacity.posterVerified ? AppColors.live : c.textTertiary,
          label: capacity.posterVerified ? l.trustVerifiedCompany : l.trustUnverifiedCompany,
          strong: capacity.posterVerified,
        ),
        const SizedBox(height: 10),
        _TrustRow(icon: Icons.star_outline, color: AppColors.accent, label: ratingText),
        if (capacity.posterAvgResponseHours != null) ...[
          const SizedBox(height: 10),
          _TrustRow(
              icon: Icons.bolt_outlined,
              color: c.textSecondary,
              label: l.responseTimeLabel(capacity.posterAvgResponseHours!)),
        ],
        const SizedBox(height: 10),
        _TrustRow(icon: Icons.location_on_outlined, color: AppColors.distance, label: capacity.location),
        const SizedBox(height: 10),
        _TrustRow(
            icon: Icons.build_outlined,
            color: c.textSecondary,
            label: '${l.tradeName(capacity.trade)} · ${capacity.workerCount} ${l.persons}'),
        if (capacity.skillDetails.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _TrustRow(icon: Icons.construction_outlined, color: c.textSecondary, label: capacity.skillDetails),
        ],
        if (capacity.dayRateBand.isNotEmpty) ...[
          const SizedBox(height: 10),
          // Prefixed with "Tagessatz" — the bare band value ("800€+") gave no
          // indication of what the number was (day rate vs. total budget vs.
          // hourly), since this row otherwise looks just like the plain
          // location/trade rows above it.
          _TrustRow(
              icon: Icons.euro_outlined,
              color: c.textSecondary,
              label:
                  '${l.dayRateBandTrustLabel}: ${l.dayRateBandName(capacity.dayRateBand)}'),
        ],
        const SizedBox(height: 12),
        Container(height: 1, color: c.border),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline, size: 14, color: c.textTertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(l.trustIdentityHiddenNote,
              style: TextStyle(fontSize: 12, color: c.textTertiary, height: 1.4))),
        ]),
      ]),
    );
  }

  Widget _buildRequestStatus(AppLocalizations l, dynamic c, ContactRequestModel req) {
    final isDeclined = req.status == 'declined';
    final color = isDeclined ? AppColors.error : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(isDeclined ? Icons.cancel_outlined : Icons.schedule, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(l.requestStatusLabel(req.status),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, height: 1.4))),
      ]),
    );
  }

  /// Optional "did it work out?" feedback, shown once contact is revealed.
  Widget _buildOutcomePrompt(AppLocalizations l, dynamic c, ContactRequestModel req) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.didItWorkOutPrompt,
          style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => _setOutcome(req, 'matched'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.live, side: const BorderSide(color: AppColors.live)),
          child: Text(l.outcomeMatchedLabel),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton(
          onPressed: () => _setOutcome(req, 'no_deal'),
          style: OutlinedButton.styleFrom(foregroundColor: c.textSecondary, side: BorderSide(color: c.border)),
          child: Text(l.outcomeNoDealLabel),
        )),
      ]),
    ]);
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

    // Owner detection — derived from the locked sidecar (the public post has
    // no companyId). _ownerDoc is only readable by owner/admin/granted, so a
    // matching posterCompanyId means "this is my own post."
    final currentUserId =
        FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null &&
        _ownerDoc != null &&
        _ownerDoc!.posterCompanyId == currentUserId;

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

                  // Anonymous-mode posts show no identity here — the
                  // subtitle stays the match context (trade · district)
                  // only. Visible/discreet posts additionally show the
                  // poster's identity below (see the block right after).
                  Text(
                    '${l.tradeName(capacity.trade)} · ${capacity.location}',
                    style: TextStyle(
                      fontSize: 16,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Poster identity — visible/discreet posts only. Tapping
                  // opens the real profile; a lightweight shell (built from
                  // just the fields already snapshotted on this post) opens
                  // the dialog instantly and self-corrects once the live
                  // company doc streams in (see CompanyModel.shellFor).
                  if (capacity.visibilityMode != CapacityVisibilityMode.anonymous &&
                      capacity.posterCompanyId != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showCompanyDetailDialog(
                        context,
                        CompanyModel.shellFor(
                          id: capacity.posterCompanyId!,
                          name: capacity.posterCompanyName ?? '',
                          logoUrl: capacity.posterLogoUrl ?? '',
                        ),
                      ),
                      child: Row(children: [
                        // CompanyLogoAvatar renders the logo via an <img> so it
                        // shows on Flutter Web (a CanvasKit-textured NetworkImage
                        // fails on the CORS-less Storage URL — see its doc).
                        CompanyLogoAvatar(
                          logoUrl: capacity.posterLogoUrl ?? '',
                          companyName: capacity.posterCompanyName ?? '',
                          radius: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            capacity.posterCompanyName ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                          ),
                        ),
                        if (capacity.posterVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 15, color: AppColors.live),
                        ],
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
                      ]),
                    ),
                  ],

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

                  // ── CONTACT — gated behind a request ──
                  _buildContactGate(l, isOwner),

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
            onSendInterest: _requestContact,
            contactGranted: _ownerDoc != null,
            onUpdateStatus: _updateStatus,
            viewerProfileComplete: _viewerCompany?.isProfileComplete ?? false,
            onProfileUpdated: _loadViewerCompany,
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
  final VoidCallback onSendInterest;
  final bool contactGranted;
  final Function(CapacityStatus) onUpdateStatus;
  final bool viewerProfileComplete;
  final VoidCallback onProfileUpdated;

  const _BottomActions({
    required this.capacity,
    required this.isOwner,
    required this.accentColor,
    required this.onPhone,
    required this.onEmail,
    required this.onSendInterest,
    required this.contactGranted,
    required this.onUpdateStatus,
    required this.viewerProfileComplete,
    required this.onProfileUpdated,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Price-proposal tip only makes sense once you're connected.
          if (viewerProfileComplete && contactGranted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: c.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.priceProposalTip,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Granted → the released contact (call / e-mail). Pre-grant, the only
          // action is a single "Interesse senden" (no direct contact exposed).
          if (viewerProfileComplete && contactGranted)
            Row(
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
            )
          else if (viewerProfileComplete)
            ElevatedButton.icon(
              onPressed: onSendInterest,
              icon: const Icon(Icons.handshake_outlined, size: 18),
              label: Text(
                l.sendInterestButton,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                minimumSize: const Size(double.infinity, 50),
                elevation: 4,
                shadowColor: accentColor.withOpacity(0.3),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.contactGateMessage,
                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CompanyProfileScreen()),
                    );
                    onProfileUpdated();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(
                    l.contactGateButton,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────────────

/// A single line in the anonymous trust block: icon + label. Never carries
/// identity — only aggregate signals (verification, rating, district, trade).
class _TrustRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool strong;

  const _TrustRow({
    required this.icon,
    required this.color,
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.3,
              color: strong ? c.textPrimary : c.textSecondary,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

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