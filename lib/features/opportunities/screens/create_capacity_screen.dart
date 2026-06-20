import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/content_moderation.dart';

// Capacify-specific trades (architecture, structural engineering, and general contractors removed)
const List<String> kCapacifyTrades = [
  'Rohbau',
  'Trockenbau',
  'Elektro',
  'Sanitär & Heizung',
  'Dach',
  'Fassade',
  'Tiefbau',
  'Stahl',
  'Beton',
  'HVAC',
  'Lieferant',
];

class CreateCapacityScreen extends ConsumerStatefulWidget {
  final CompanyModel company;

  const CreateCapacityScreen({
    super.key,
    required this.company,
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

  CapacityType _type = CapacityType.offer;
  String _selectedTrade = '';
  AvailabilityType _availabilityType = AvailabilityType.thisWeek;
  String _selectedDistrict = '';
  int _workerCount = 1;
  bool _isPosting = false;

  bool get _isValid =>
      _selectedTrade.isNotEmpty &&
      _selectedDistrict.isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // initialize worker count controller with default value
    _workerCountController.text = '$_workerCount';
  }

  @override
  void dispose() {
    _workerCountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final l = AppLocalizations.of(context);
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

      final typeWord = _type == CapacityType.offer ? 'verfügbar' : 'gesucht';

      final capacity = CapacityModel(
        id: '',
        companyId: widget.company.id,
        companyName: widget.company.name,
        companyCity: widget.company.city,
        companyPhone: widget.company.phone,
        companyEmail: widget.company.email,
        type: _type,
        status: CapacityStatus.active,
        availabilityType: _availabilityType,
        title: '$_workerCount $_selectedTrade $typeWord',
        description: _descriptionController.text.trim(),
        trade: _selectedTrade,
        location: _selectedDistrict,
        workerCount: _workerCount,
        availableFrom: _availableFrom ?? now,
        availableTo: _availableFrom != null ? (_availableTo ?? availableTo) : availableTo,
        contentFlagged: containsBlockedContent(_descriptionController.text),
      );

      await ref.read(capacityServiceProvider).createCapacity(capacity);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(capacity.contentFlagged ? l.postingUnderReviewNotice : l.capacityNowLive),
            backgroundColor: capacity.contentFlagged ? AppColors.accent : AppColors.live,
          ),
        );
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

                  const SizedBox(height: 24),

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

                  const SizedBox(height: 28),

                  // SECTION 2: TRADE SELECTOR (VISUAL GRID)
                  _SectionLabel(
                    label: l.section2Trade,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kCapacifyTrades.map((trade) {
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

                  const SizedBox(height: 28),

                  // SECTION 3: AVAILABILITY
                  _SectionLabel(label: l.section3When),
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

                  const SizedBox(height: 28),

                  // SECTION 4: HAMBURG DISTRICT
                  _SectionLabel(
                    label: l.section4LocationHamburg,
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

                  const SizedBox(height: 28),

                  // SECTION 5: WORKER COUNT
                  _SectionLabel(label: l.section5WorkerCount),
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
                          l.persons,
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
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // SECTION 6: DESCRIPTION
                  _SectionLabel(
                    label: l.section6Description,
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

                  const SizedBox(height: 100),
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
                                '$_workerCount ${l.tradeName(_selectedTrade)} ${_type == CapacityType.offer ? l.titleAvailableSuffix : l.titleWantedSuffix}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                '$_selectedDistrict · ${_availabilityType == AvailabilityType.now ? l.availNowBadge : _availabilityType == AvailabilityType.thisWeek ? l.availThisWeekBadge : l.availNextWeekBadge}',
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : c.border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : c.textSecondary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? color : c.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
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
            Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  surface: AppColors.surface,
                ),
              ),
              child: CalendarDatePicker(
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
