import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/models/company_rating_model.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../../core/services/analytics_service.dart';

/// Opens a company's profile as a compact popup instead of pushing a
/// full-screen route — mirrors showCapacityDetailDialog so both post and
/// company cards open the same way, and callers (directory grid, admin
/// action center) keep their scroll position underneath.
void showCompanyDetailDialog(BuildContext context, CompanyModel company) {
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
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CompanyDetailScreen(company: company)),
        ),
      ),
    ),
  );
}

class CompanyDetailScreen extends ConsumerWidget {
  final CompanyModel company;

  const CompanyDetailScreen({super.key, required this.company});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('CompanyDetail'));
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final isOwnCompany = currentUserId != null && currentUserId == company.id;
    final companyAsync = ref.watch(companyByIdProvider(company.id));
    final liveCompany = companyAsync.value ?? company;
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: c.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          company.name,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero section
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Builder(builder: (context) {
                  final avatar = CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      company.name.isNotEmpty
                          ? company.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                  );

                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Trade badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: company.trades.map((trade) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            l.tradeName(trade),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                      // Location and employees
                      Wrap(
                        spacing: 4,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: c.textSecondary,
                          ),
                          Text(
                            company.city.isNotEmpty
                                ? company.city
                                : l.noLocationText,
                            style: TextStyle(
                              fontSize: 14,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.people_outline,
                            size: 16,
                            color: c.textSecondary,
                          ),
                          Text(
                            l.employeesSuffix(company.employees),
                            style: TextStyle(
                              fontSize: 14,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Trust/liveness: member-since + last-active (only shown
                      // when recent, so it never reads as a negative "inactive").
                      Builder(builder: (_) {
                        String? activeLabel;
                        final la = company.lastActiveAt;
                        if (la != null) {
                          final d = DateTime.now().difference(la).inDays;
                          if (d <= 0) {
                            activeLabel = l.activeTodayLabel;
                          } else if (d == 1) {
                            activeLabel = l.activeYesterdayLabel;
                          } else if (d <= 14) {
                            activeLabel = l.activeDaysAgoLabel(d);
                          }
                        }
                        final respHours = company.avgResponseHours;
                        if (company.createdAt == null &&
                            activeLabel == null &&
                            respHours == null &&
                            company.completedCollaborations == 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            if (company.createdAt != null)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.event_available_outlined, size: 15, color: c.textTertiary),
                                const SizedBox(width: 5),
                                Text(l.memberSinceLabel(company.createdAt!.year),
                                    style: TextStyle(fontSize: 13, color: c.textTertiary)),
                              ]),
                            if (activeLabel != null)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(activeLabel,
                                    style: const TextStyle(fontSize: 13, color: AppColors.live, fontWeight: FontWeight.w700)),
                              ]),
                            if (respHours != null)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.bolt_outlined, size: 15, color: c.textTertiary),
                                const SizedBox(width: 5),
                                Text(l.responseTimeLabel(respHours),
                                    style: TextStyle(fontSize: 13, color: c.textTertiary)),
                              ]),
                            if (company.completedCollaborations > 0)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.handshake_outlined, size: 15, color: AppColors.live),
                                const SizedBox(width: 5),
                                Text(
                                  company.repeatCollaborations > 0
                                      ? '${l.collabCountLabel(company.completedCollaborations)} · ${l.collabRepeatLabel(company.repeatCollaborations)}'
                                      : l.collabCountLabel(company.completedCollaborations),
                                  style: const TextStyle(fontSize: 13, color: AppColors.live, fontWeight: FontWeight.w700),
                                ),
                              ]),
                          ]),
                        );
                      }),
                    ],
                  );

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [avatar, const SizedBox(height: 16), info],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: 24),
                      Expanded(child: info),
                    ],
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Rating bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Builder(builder: (context) {
                  final summary = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StarRatingDisplay(rating: liveCompany.avgRating, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        liveCompany.ratingCount > 0
                            ? '${liveCompany.avgRating.toStringAsFixed(1)} (${liveCompany.ratingCount})'
                            : l.noReviewsYetText,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textSecondary),
                      ),
                    ],
                  );
                  final rateButton = (!isOwnCompany && currentUserId != null)
                      ? _RateButton(companyId: company.id, currentUserId: currentUserId, companyName: company.name)
                      : null;

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        summary,
                        if (rateButton != null) ...[
                          const SizedBox(height: 12),
                          Align(alignment: Alignment.centerLeft, child: rateButton),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      summary,
                      const Spacer(),
                      if (rateButton != null) rateButton,
                    ],
                  );
                }),
              ),

              const SizedBox(height: 24),

              // About
              _DetailSection(
                title: l.aboutCompanySection,
                child: Text(
                  company.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Qualifications & memberships — a self-declared trust signal.
              if (company.certifications.trim().isNotEmpty) ...[
                _DetailSection(
                  title: l.certificationsTitle,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_outlined,
                          size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          company.certifications,
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Services
              if (company.services.isNotEmpty) ...[
                _DetailSection(
                  title: l.servicesLabel,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: company.services
                        .map(
                          (service) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: c.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: c.border),
                            ),
                            child: Text(
                              service,
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Contact
              _DetailSection(
                title: l.contactLabel,
                child: Column(
                  children: [
                    if (company.email.isNotEmpty)
                      _ContactRow(
                        icon: Icons.email_outlined,
                        value: company.email,
                      ),
                    if (company.phone.isNotEmpty)
                      _ContactRow(
                        icon: Icons.phone_outlined,
                        value: company.phone,
                      ),
                    if (company.website.isNotEmpty)
                      _ContactRow(
                        icon: Icons.language_outlined,
                        value: company.website,
                      ),
                    if (company.address.isNotEmpty)
                      _ContactRow(
                        icon: Icons.location_on_outlined,
                        value:
                            '${company.address}, ${company.postalCode} ${company.city}',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Reviews
              _DetailSection(
                title: l.reviewsSectionTitle,
                child: Consumer(
                  builder: (context, ref, _) {
                    final ratingsAsync = ref.watch(companyRatingsProvider(company.id));
                    return ratingsAsync.when(
                      data: (ratings) {
                        if (ratings.isEmpty) {
                          return Text(l.noReviewsYetText, style: TextStyle(fontSize: 14, color: c.textTertiary));
                        }
                        return Column(
                          children: ratings.map((r) => _ReviewCard(rating: r)).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (e, _) => Text(l.errorWithMessage(e), style: const TextStyle(color: AppColors.error)),
                    );
                  },
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

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: c.border),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RATE BUTTON ─────────────────────────────────────

class _RateButton extends ConsumerWidget {
  final String companyId;
  final String currentUserId;
  final String companyName;

  const _RateButton({
    required this.companyId,
    required this.currentUserId,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final myRatingAsync = ref.watch(
      myRatingForCompanyProvider((companyId: companyId, userId: currentUserId)),
    );
    final myCompanyAsync = ref.watch(myCompanyProvider(currentUserId));
    final existingRating = myRatingAsync.value;
    final raterCompanyName = myCompanyAsync.value?.name ?? '';

    return OutlinedButton.icon(
      onPressed: raterCompanyName.isEmpty
          ? null
          : () => showDialog(
                context: context,
                builder: (_) => _RateCompanyDialog(
                  companyId: companyId,
                  companyName: companyName,
                  raterUserId: currentUserId,
                  raterCompanyName: raterCompanyName,
                  existingRating: existingRating,
                ),
              ),
      icon: const Icon(Icons.star_outline, size: 16),
      label: Text(existingRating != null ? l.editRatingButton : l.rateCompanyButton),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

// ─── RATE DIALOG ─────────────────────────────────────

class _RateCompanyDialog extends ConsumerStatefulWidget {
  final String companyId;
  final String companyName;
  final String raterUserId;
  final String raterCompanyName;
  final CompanyRatingModel? existingRating;

  const _RateCompanyDialog({
    required this.companyId,
    required this.companyName,
    required this.raterUserId,
    required this.raterCompanyName,
    this.existingRating,
  });

  @override
  ConsumerState<_RateCompanyDialog> createState() => _RateCompanyDialogState();
}

class _RateCompanyDialogState extends ConsumerState<_RateCompanyDialog> {
  late int _selected;
  late final TextEditingController _commentController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.existingRating?.rating ?? 0;
    _commentController = TextEditingController(text: widget.existingRating?.comment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_selected == 0) {
      setState(() => _error = l.selectRatingValidation);
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(companyServiceProvider).submitRating(
            companyId: widget.companyId,
            raterUserId: widget.raterUserId,
            raterCompanyName: widget.raterCompanyName,
            rating: _selected,
            comment: _commentController.text.trim(),
          );
      // myRatingForCompanyProvider is a one-time FutureProvider (not a
      // stream), so it won't pick up this change on its own — invalidate
      // it so the "Bewerten"/"Bewertung bearbeiten" button reflects the
      // new rating immediately rather than on next full page load.
      ref.invalidate(myRatingForCompanyProvider((companyId: widget.companyId, userId: widget.raterUserId)));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.ratingSubmittedSuccess), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = l.errorWithMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final c = AppColors.of(context);
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

    setState(() => _isSaving = true);
    try {
      await ref.read(companyServiceProvider).deleteRating(
            ratingId: widget.existingRating!.id,
            companyId: widget.companyId,
          );
      ref.invalidate(myRatingForCompanyProvider((companyId: widget.companyId, userId: widget.raterUserId)));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.ratingDeletedSnackbar), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = l.errorWithMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.rateCompanyDialogTitle(widget.companyName),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary),
            ),
            const SizedBox(height: 20),
            Text(l.yourRatingLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const SizedBox(height: 8),
            StarRatingInput(value: _selected, onChanged: (v) => setState(() => _selected = v)),
            const SizedBox(height: 20),
            Text(l.commentOptionalLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(hintText: l.commentOptionalHint),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.existingRating != null) ...[
                  TextButton(
                    onPressed: _isSaving ? null : _delete,
                    child: Text(l.deleteRatingButton, style: const TextStyle(color: AppColors.error)),
                  ),
                  const Spacer(),
                ],
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l.submitRatingButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── REVIEW CARD ─────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final CompanyRatingModel rating;
  const _ReviewCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final date = rating.updatedAt ?? rating.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rating.raterCompanyName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (date != null)
                Text(
                  '${date.day}.${date.month}.${date.year}',
                  style: TextStyle(fontSize: 11, color: c.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          StarRatingDisplay(rating: rating.rating.toDouble(), size: 14),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.comment,
              style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}