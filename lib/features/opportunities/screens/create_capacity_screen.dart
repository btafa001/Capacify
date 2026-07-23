import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/capacity_owner_model.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/form_draft_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/content_moderation.dart';
import '../../../core/services/analytics_service.dart';
import '../../../shared/widgets/milestone.dart';
import '../../../core/router/app_router.dart' show rootNavigatorKey;

class CreateCapacityScreen extends ConsumerStatefulWidget {
  final CompanyModel company;

  /// When set, the post is submitted through this callback (receiving both the
  /// anonymized post and its identity sidecar) instead of the default
  /// `capacityServiceProvider.createCapacity()`. Used by the admin-assisted
  /// onboarding wizard to route both writes through a secondary Firebase
  /// session (so they're owned by the new company, not the admin). Null for
  /// every normal call site — those behave exactly as before.
  final Future<void> Function(CapacityModel, CapacityOwnerModel)? onSubmitOverride;

  /// Optional prefill — "Erneut posten" (repost) passes a previous post so the
  /// form opens pre-filled and publishing is a 1-change, sub-10-second action.
  final CapacityModel? prefill;

  const CreateCapacityScreen({
    super.key,
    required this.company,
    this.onSubmitOverride,
    this.prefill,
  });

  @override
  ConsumerState<CreateCapacityScreen> createState() =>
      _CreateCapacityScreenState();
}

class _CreateCapacityScreenState extends ConsumerState<CreateCapacityScreen> {
  // State fields (moved here to avoid top-level duplicates)
  DateTime? _availableFrom;
  DateTime? _availableTo;

  final TextEditingController _workerCountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _skillDetailsController = TextEditingController();

  CapacityType _type = CapacityType.offer;
  CapacityVisibilityMode _visibilityMode = CapacityVisibilityMode.visible;
  String _selectedTrade = '';
  AvailabilityType _availabilityType = AvailabilityType.thisWeek;
  String _selectedDistrict = '';
  int _workerCount = 1;
  String _dayRateBand = '';
  bool _isPosting = false;

  // Description is optional — trade + district are the only required fields.
  bool get _isValid =>
      _selectedTrade.isNotEmpty && _selectedDistrict.isNotEmpty;

  // Draft-save — same rationale/pattern as register_screen.dart. Never
  // restored over an explicit repost prefill (that's already an intentional,
  // different kind of pre-fill).
  static const _draftKey = 'draft_create_capacity';
  Timer? _draftTimer;
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('CreateCapacity');
    final p = widget.prefill;
    if (p != null) {
      // Repost: reopen a previous post pre-filled (change one field → publish).
      _type = p.type;
      _visibilityMode = p.visibilityMode;
      _selectedTrade = p.trade;
      _availabilityType = p.availabilityType;
      _selectedDistrict = p.location;
      _workerCount = p.workerCount;
      _descriptionController.text = p.description;
      _dayRateBand = p.dayRateBand;
      _skillDetailsController.text = p.skillDetails;
    } else {
      // Smart defaults: pre-select the company's primary trade so a first-time
      // poster starts one step ahead.
      if (widget.company.trades.isNotEmpty) {
        _selectedTrade = widget.company.trades.first;
      }
      _restoreDraft();
    }
    _workerCountController.text = '$_workerCount';
    _draftTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraft());
  }

  void _restoreDraft() {
    final draft = FormDraftService.load(_draftKey);
    if (draft == null) return;
    final trade = draft['selectedTrade'] as String?;
    if (trade != null && kTrades.contains(trade)) _selectedTrade = trade;
    final district = draft['selectedDistrict'] as String?;
    if (district != null && kHamburgDistricts.contains(district)) _selectedDistrict = district;
    _type = (draft['type'] as String?) == 'need' ? CapacityType.need : CapacityType.offer;
    _visibilityMode = CapacityVisibilityMode.values.firstWhere(
      (m) => m.name == draft['visibilityMode'],
      orElse: () => _visibilityMode,
    );
    _availabilityType = AvailabilityType.values.firstWhere(
      (t) => t.name == draft['availabilityType'],
      orElse: () => _availabilityType,
    );
    _workerCount = draft['workerCount'] as int? ?? _workerCount;
    _descriptionController.text = draft['description'] as String? ?? '';
    _skillDetailsController.text = draft['skillDetails'] as String? ?? '';
    _dayRateBand = draft['dayRateBand'] as String? ?? '';
    final from = draft['availableFrom'] as String?;
    final to = draft['availableTo'] as String?;
    if (from != null) _availableFrom = DateTime.tryParse(from);
    if (to != null) _availableTo = DateTime.tryParse(to);
  }

  void _saveDraft() {
    if (_selectedTrade.isEmpty &&
        _selectedDistrict.isEmpty &&
        _descriptionController.text.trim().isEmpty &&
        _skillDetailsController.text.trim().isEmpty) {
      return;
    }
    FormDraftService.save(_draftKey, {
      'selectedTrade': _selectedTrade,
      'selectedDistrict': _selectedDistrict,
      'type': _type == CapacityType.need ? 'need' : 'offer',
      'visibilityMode': _visibilityMode.name,
      'availabilityType': _availabilityType.name,
      'workerCount': _workerCount,
      'description': _descriptionController.text,
      'skillDetails': _skillDetailsController.text,
      'dayRateBand': _dayRateBand,
      if (_availableFrom != null) 'availableFrom': _availableFrom!.toIso8601String(),
      if (_availableTo != null) 'availableTo': _availableTo!.toIso8601String(),
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (!_posted) _saveDraft();
    _workerCountController.dispose();
    _descriptionController.dispose();
    _skillDetailsController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final l = AppLocalizations.of(context);
    if (widget.company.suspended) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.accountSuspendedPostBlocked(widget.company.suspensionReason)),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.fillTradeLocationDescription),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      final now = DateTime.now();
      final availableTo = _availabilityType == AvailabilityType.now
          ? now.add(const Duration(days: 3))
          : _availabilityType == AvailabilityType.thisWeek
              ? now.add(const Duration(days: 7))
              : now.add(const Duration(days: 14));

      final capacity = CapacityModel(
        id: '',
        type: _type,
        status: CapacityStatus.active,
        availabilityType: _availabilityType,
        // Crew-led title ("Maler-Kolonne verfügbar"), matching autoTitle() —
        // never headcount-first ("3 Maler verfügbar").
        title: _type == CapacityType.offer
            ? l.postTitleOffer(l.tradeName(_selectedTrade))
            : l.postTitleNeed(l.tradeName(_selectedTrade)),
        description: _descriptionController.text.trim(),
        trade: _selectedTrade,
        location: _selectedDistrict,
        workerCount: _workerCount,
        availableFrom: _availableFrom ?? now,
        availableTo: _availableFrom != null ? (_availableTo ?? availableTo) : availableTo,
        contentFlagged: shouldFlagDescription(_descriptionController.text),
        // Non-identifying trust signals snapshotted from the company.
        posterVerified: widget.company.isVerified,
        posterRatingSum: widget.company.ratingSum,
        posterRatingCount: widget.company.ratingCount,
        posterSuspended: widget.company.suspended,
        posterAvgResponseHours: widget.company.avgResponseHours,
        districtCoordinates: CapacityModel.coordinatesForLocation(_selectedDistrict),
        dayRateBand: _dayRateBand,
        skillDetails: _skillDetailsController.text.trim(),
        visibilityMode: _visibilityMode,
        posterCompanyId: _visibilityMode == CapacityVisibilityMode.anonymous ? null : widget.company.id,
        posterCompanyName: _visibilityMode == CapacityVisibilityMode.anonymous ? null : widget.company.name,
        posterLogoUrl: _visibilityMode == CapacityVisibilityMode.anonymous || widget.company.logoUrl.isEmpty
            ? null
            : widget.company.logoUrl,
      );

      // The identity sidecar — written to the locked capacityOwners/{id},
      // never to the public post. Contact is snapshotted from the company.
      final owner = CapacityOwnerModel(
        postId: '',
        posterCompanyId: widget.company.id,
        companyName: widget.company.name,
        contactPhone: widget.company.phone,
        contactEmail: widget.company.email,
      );

      if (widget.onSubmitOverride != null) {
        await widget.onSubmitOverride!(capacity, owner);
      } else {
        await ref.read(capacityServiceProvider).createCapacity(capacity, owner: owner);
      }

      AnalyticsService.logEvent('capacity_created', parameters: {'trade': _selectedTrade});
      _posted = true;
      FormDraftService.clear(_draftKey);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(capacity.contentFlagged ? l.postingUnderReviewNotice : l.capacityNowLive),
            backgroundColor: capacity.contentFlagged ? AppColors.accent : AppColors.live,
          ),
        );
        // Wow moment: first live post. Fire on the root navigator (this screen
        // just popped) so it lands on the feed. Not for flagged/under-review.
        if (!capacity.contentFlagged) {
          final rootCtx = rootNavigatorKey.currentContext;
          if (rootCtx != null) {
            Milestone.celebrateOnce(rootCtx,
                uid: widget.company.id,
                key: 'first_post',
                icon: Icons.rocket_launch_outlined,
                title: l.msFirstPostTitle,
                subtitle: l.msFirstPostBody);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.errorWithMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: c.textPrimary,
          ),
          tooltip: l.closeTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.navPostCapacity,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              l.thirtySecondsToLive,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: c.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          child: Text(
                            widget.company.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.company.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // SECTION 1: TYPE SELECTOR
                  _SectionLabel(
                    label: l.section1Type,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeButton(
                          label: l.offerLabel,
                          subtitle: l.weAreAvailable,
                          icon: Icons.volunteer_activism,
                          isSelected: _type == CapacityType.offer,
                          color: AppColors.live,
                          onTap: () => setState(
                            () => _type = CapacityType.offer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeButton(
                          label: l.needLabel,
                          subtitle: l.weAreSearching,
                          icon: Icons.search,
                          isSelected: _type == CapacityType.need,
                          color: AppColors.accent,
                          onTap: () => setState(
                            () => _type = CapacityType.need,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SECTION 2: VISIBILITY MODE — chosen once, immutable
                  // after posting (see CapacityModel.visibilityMode).
                  // Placed right after Type since it's as fundamental a
                  // choice as offer/need.
                  _SectionLabel(label: l.section2Visibility),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      _VisibilityButton(
                        label: l.visibilityVisibleLabel,
                        subtitle: l.visibilityVisibleSubtitle,
                        icon: Icons.storefront_outlined,
                        color: AppColors.live,
                        isSelected: _visibilityMode == CapacityVisibilityMode.visible,
                        onTap: () => setState(() => _visibilityMode = CapacityVisibilityMode.visible),
                      ),
                      const SizedBox(height: 8),
                      _VisibilityButton(
                        label: l.visibilityDiscreetLabel,
                        subtitle: l.visibilityDiscreetSubtitle,
                        icon: Icons.shield_outlined,
                        color: AppColors.distance,
                        isSelected: _visibilityMode == CapacityVisibilityMode.discreet,
                        onTap: () => setState(() => _visibilityMode = CapacityVisibilityMode.discreet),
                      ),
                      const SizedBox(height: 8),
                      _VisibilityButton(
                        label: l.visibilityAnonymousLabel,
                        subtitle: l.visibilityAnonymousSubtitle,
                        icon: Icons.visibility_off_outlined,
                        color: c.textSecondary,
                        isSelected: _visibilityMode == CapacityVisibilityMode.anonymous,
                        onTap: () => setState(() => _visibilityMode = CapacityVisibilityMode.anonymous),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SECTION 3: TRADE SELECTOR (VISUAL GRID)
                  _SectionLabel(
                    label: l.section3Trade,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kTrades.map((trade) {
                      final isSelected = _selectedTrade == trade;
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedTrade = trade,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.2)
                                : c.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : c.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            l.tradeName(trade),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              color: isSelected ? AppColors.primary : c.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 4: AVAILABILITY
                  _SectionLabel(label: l.section4When),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      _AvailabilityButton(
                        label: l.availNowAllCaps,
                        subtitle: l.availableFromTodaySubtitle,
                        type: AvailabilityType.now,
                        color: AppColors.live,
                        isSelected: _availabilityType == AvailabilityType.now,
                        onTap: () => setState(() => _availabilityType = AvailabilityType.now),
                      ),
                      const SizedBox(height: 8),
                      _AvailabilityButton(
                        label: l.availThisWeekBadge,
                        subtitle: l.within7DaysSubtitle,
                        type: AvailabilityType.thisWeek,
                        color: AppColors.accent,
                        isSelected: _availabilityType == AvailabilityType.thisWeek,
                        onTap: () => setState(() => _availabilityType = AvailabilityType.thisWeek),
                      ),
                      const SizedBox(height: 8),
                      _AvailabilityButton(
                        label: l.availNextWeekBadge,
                        subtitle: l.in7to14DaysSubtitle,
                        type: AvailabilityType.nextWeek,
                        color: c.textSecondary,
                        isSelected: _availabilityType == AvailabilityType.nextWeek,
                        onTap: () => setState(() => _availabilityType = AvailabilityType.nextWeek),
                      ),
                      const SizedBox(height: 8),
                      // Custom date range button
                      GestureDetector(
                        onTap: () async {
                          final now = DateTime.now();
                          final defaultStart = now.add(const Duration(days: 1));
                          final initialStart = (_availableFrom != null && _availableFrom!.isAfter(now))
                              ? _availableFrom!
                              : defaultStart;
                          final initialEnd = (_availableTo != null && _availableTo!.isAfter(initialStart))
                              ? _availableTo!
                              : initialStart.add(const Duration(days: 7));

                          final picked = await showDialog<DateTimeRange>(
                            context: context,
                            builder: (_) => _DateRangePickerDialog(
                              initialStart: initialStart,
                              initialEnd: initialEnd,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365)),
                            ),
                          );
                          if (picked == null) return;

                          setState(() {
                            _availabilityType = AvailabilityType.custom;
                            _availableFrom = picked.start;
                            _availableTo = picked.end;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _availabilityType == AvailabilityType.custom
                                ? AppColors.distance.withOpacity(0.12)
                                : c.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _availabilityType == AvailabilityType.custom ? AppColors.distance : c.border,
                              width: _availabilityType == AvailabilityType.custom ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _availabilityType == AvailabilityType.custom ? AppColors.distance : c.border,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _availabilityType == AvailabilityType.custom &&
                                              _availableFrom != null &&
                                              _availableTo != null
                                          ? '${_availableFrom!.day}.${_availableFrom!.month}. – ${_availableTo!.day}.${_availableTo!.month}.${_availableTo!.year}'
                                          : l.chooseDateLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _availabilityType == AvailabilityType.custom ? AppColors.distance : c.textPrimary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      l.chooseDateFromCalendar,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: _availabilityType == AvailabilityType.custom ? AppColors.distance : c.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SECTION 5: HAMBURG DISTRICT
                  _SectionLabel(
                    label: l.section5LocationHamburg,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kHamburgDistricts.map((district) {
                      final isSelected = _selectedDistrict == district;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDistrict = district),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.distance.withOpacity(0.2) : c.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AppColors.distance : c.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            district,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              color: isSelected ? AppColors.distance : c.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 6: WORKER COUNT
                  _SectionLabel(label: l.section6WorkerCount),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          l.teamSizeLabel,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _workerCount > 1
                              ? () => setState(() {
                                    _workerCount--;
                                    _workerCountController.text = '$_workerCount';
                                  })
                              : null,
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          tooltip: l.decreaseTeamSizeTooltip,
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _workerCountController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                setState(() => _workerCount = parsed);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: _workerCount < 100
                              ? () => setState(() {
                                    _workerCount++;
                                    _workerCountController.text = '$_workerCount';
                                  })
                              : null,
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          tooltip: l.increaseTeamSizeTooltip,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 7: DESCRIPTION
                  _SectionLabel(
                    label: l.section7Description,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    maxLength: 150,
                    maxLines: 3,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                    ),
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l.descriptionExampleHint,
                      hintStyle: TextStyle(
                        color: c.textTertiary,
                        fontSize: 13,
                      ),
                      counterStyle: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 8: ADDITIONAL DETAILS (optional) — CapacityOS
                  // readiness: skill/equipment granularity below the fixed
                  // trade list, and a self-reported day-rate band (left
                  // unset by default — day rates are commercially sensitive,
                  // so disclosing one is each company's own call, never
                  // required by this form).
                  _SectionLabel(label: l.section8AdditionalDetails),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _skillDetailsController,
                    maxLength: 120,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: l.skillDetailsLabel,
                      hintText: l.skillDetailsHint,
                      hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
                      counterStyle: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.dayRateBandLabel,
                      style: TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [null, ...kDayRateBands].map((band) {
                      final isSelected = _dayRateBand == (band ?? '');
                      return GestureDetector(
                        onTap: () => setState(() => _dayRateBand = band ?? ''),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.2) : c.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : c.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            band == null ? l.dayRateBandUndisclosed : l.dayRateBandName(band),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              color: isSelected ? AppColors.primary : c.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Sticky bottom post button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(
                top: BorderSide(color: c.border),
              ),
            ),
            child: Column(
              children: [
                // Preview of what will be posted
                if (_selectedTrade.isNotEmpty && _selectedDistrict.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _type == CapacityType.offer ? AppColors.live : AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _type == CapacityType.offer
                                    ? l.postTitleOffer(l.tradeName(_selectedTrade))
                                    : l.postTitleNeed(l.tradeName(_selectedTrade)),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                '$_workerCount ${l.persons} · $_selectedDistrict · ${_availabilityType == AvailabilityType.now ? l.availNowBadge : _availabilityType == AvailabilityType.thisWeek ? l.availThisWeekBadge : l.availNextWeekBadge}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: c.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.previewLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isPosting ? null : _post,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isPosting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                l.postNowButton,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Small helper widgets used in this file (kept minimal and inline)

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: c.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Fixed minHeight (not IntrinsicHeight+stretch) — IntrinsicHeight
        // underestimates here because it measures each Expanded child's
        // intrinsic height before the Row's flex pass narrows it to half
        // the width, so it doesn't account for the subtitle wrapping to a
        // second line at the actual (halved) width, causing overflow. A
        // fixed minHeight sized for the worst-case 2-line subtitle avoids
        // that entirely and keeps both buttons the same height regardless
        // of how either subtitle wraps.
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : c.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : c.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? color : c.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final AvailabilityType type;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvailabilityButton({
    required this.label,
    required this.subtitle,
    required this.type,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : c.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? color : c.border)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? color : c.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 16, color: isSelected ? color : c.textSecondary),
          ],
        ),
      ),
    );
  }
}

// Same visual shape as _AvailabilityButton (full-width row, dot indicator,
// label+subtitle, trailing icon) — a dedicated widget rather than reusing
// _AvailabilityButton directly since that one is typed to AvailabilityType.
class _VisibilityButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : c.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? color : c.border)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? color : c.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.3)),
                ],
              ),
            ),
            Icon(icon, size: 16, color: isSelected ? color : c.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── CUSTOM DATE RANGE PICKER ───────────────────────
//
// A single compact dialog (same size as the stock single-date picker)
// that lets the user pick a start and end date, always showing both as
// tappable chips above the calendar so neither selection is hidden.

class _DateRangePickerDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DateRangePickerDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late DateTime _start;
  late DateTime _end;
  bool _pickingStart = true;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  String _fmt(DateTime d) => '${d.day}.${d.month}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 328),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _StepChip(
                      label: l.startDateChip,
                      value: _fmt(_start),
                      active: _pickingStart,
                      onTap: () => setState(() => _pickingStart = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: c.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StepChip(
                      label: l.endDateChip,
                      value: _fmt(_end),
                      active: !_pickingStart,
                      onTap: () => setState(() => _pickingStart = false),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.border, height: 1),
            CalendarDatePicker(
              key: ValueKey(_pickingStart),
              initialDate: _pickingStart ? _start : _end,
              firstDate: _pickingStart ? widget.firstDate : _start,
              lastDate: widget.lastDate,
              onDateChanged: (date) {
                setState(() {
                  if (_pickingStart) {
                    _start = date;
                    if (_end.isBefore(_start)) {
                      _end = _start.add(const Duration(days: 7));
                    }
                    _pickingStart = false;
                  } else {
                    _end = date;
                  }
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context, DateTimeRange(start: _start, end: _end)),
                    child: Text(l.confirmGenericLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  const _StepChip({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.12) : c.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : c.border, width: active ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? AppColors.primary : c.textTertiary)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? AppColors.primary : c.textPrimary)),
          ],
        ),
      ),
    );
  }
}
