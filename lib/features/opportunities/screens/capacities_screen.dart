import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/services/company_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/report_model.dart';
import '../../../core/services/report_provider.dart';
import '../../../shared/widgets/star_rating.dart';
import 'create_capacity_screen.dart';
import 'capacity_detail_screen.dart';

class CapacitiesScreen extends ConsumerStatefulWidget {
  const CapacitiesScreen({super.key});

  @override
  ConsumerState<CapacitiesScreen> createState() => _CapacitiesScreenState();
}

class _CapacitiesScreenState extends ConsumerState<CapacitiesScreen> {
  // null = all trades / all types
  String? _selectedTrade;
  CapacityType? _selectedType;
  String _searchText = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final l = AppLocalizations.of(context);
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final company = await ref.read(companyServiceProvider).getCompanyByOwner(user.uid);
    if (!mounted) return;
    if (company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.requireCompany), backgroundColor: AppColors.error),
      );
      return;
    }
    final size = MediaQuery.of(context).size;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: l.closeLabel,
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

  List<CapacityModel> _filter(List<CapacityModel> items) {
    return items.where((c) {
      final matchesTrade  = _selectedTrade == null || c.trade == _selectedTrade;
      final matchesType   = _selectedType  == null || c.type == _selectedType;
      final matchesSearch = _searchText.isEmpty ||
          c.title.toLowerCase().contains(_searchText.toLowerCase()) ||
          c.location.toLowerCase().contains(_searchText.toLowerCase()) ||
          c.companyName.toLowerCase().contains(_searchText.toLowerCase());
      return matchesTrade && matchesType && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final capacitiesAsync = ref.watch(capacitiesProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final trades = [
      'Generalunternehmer', 'Rohbau', 'Trockenbau', 'Elektro',
      'Sanitär & Heizung', 'Dach', 'Fassade', 'Tiefbau',
      'Architektur', 'Statik', 'Stahl', 'Beton', 'HVAC', 'Lieferant',
    ];

    final tradeDrop = DropdownButtonFormField<String?>(
      value: _selectedTrade,
      dropdownColor: c.surface,
      style: TextStyle(color: c.textPrimary),
      decoration: const InputDecoration(),
      items: [
        DropdownMenuItem(value: null, child: Text(l.tradeAll)),
        ...trades.map((t) => DropdownMenuItem(value: t, child: Text(l.tradeName(t)))),
      ],
      onChanged: (v) => setState(() => _selectedTrade = v),
    );

    final typeDrop = DropdownButtonFormField<CapacityType?>(
      value: _selectedType,
      dropdownColor: c.surface,
      style: TextStyle(color: c.textPrimary),
      decoration: const InputDecoration(),
      items: [
        DropdownMenuItem(value: null,               child: Text(l.typeAll)),
        DropdownMenuItem(value: CapacityType.offer, child: Text(l.typeOffer)),
        DropdownMenuItem(value: CapacityType.need,  child: Text(l.typeNeed)),
      ],
      onChanged: (v) => setState(() => _selectedType = v),
    );

    final searchField = TextField(
      controller: _searchController,
      style: TextStyle(color: c.textPrimary),
      onChanged: (v) => setState(() => _searchText = v),
      decoration: InputDecoration(
        hintText: l.searchHint,
        prefixIcon: Icon(Icons.search, color: c.textSecondary, size: 20),
      ),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            if (isMobile) ...[
              Text(l.capacitiesTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(l.capacitiesSubtitle, style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.capacitiesAddBtn),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.capacitiesTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.textPrimary)),
                      const SizedBox(height: 4),
                      Text(l.capacitiesSubtitle, style: TextStyle(fontSize: 14, color: c.textSecondary)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.capacitiesAddBtn),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(180, 44)),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // ── Filters ──
            if (isMobile) ...[
              searchField,
              const SizedBox(height: 10),
              Row(children: [Expanded(child: tradeDrop), const SizedBox(width: 10), Expanded(child: typeDrop)]),
            ] else
              Row(children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: tradeDrop),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: typeDrop),
              ]),

            const SizedBox(height: 24),

            Expanded(
              child: capacitiesAsync.when(
                data: (capacities) {
                  final filtered = _filter(capacities);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: c.textHint),
                          const SizedBox(height: 16),
                          Text(l.noCapacitiesFound, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.textSecondary)),
                          const SizedBox(height: 8),
                          Text(l.addFirstCapacity, style: TextStyle(fontSize: 14, color: c.textHint)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _CapacityCard(capacity: filtered[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text(l.errorWithMessage(e), style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Capacity Card ────────────────────────────────────────────────────────────

class _CapacityCard extends StatelessWidget {
  final CapacityModel capacity;
  const _CapacityCard({required this.capacity});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isOffer  = capacity.type == CapacityType.offer;
    final typeColor = isOffer ? AppColors.success : AppColors.accent;
    final typeLabel = isOffer ? l.offerLabel : l.needLabel;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CapacityDetailScreen(capacity: capacity))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 80, decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: typeColor.withOpacity(0.3))),
                        child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                        child: Text(l.tradeName(capacity.trade), style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      Builder(builder: (_) {
                        final now = DateTime.now();
                        final isExpired = now.isAfter(capacity.availableTo);
                        final days = capacity.availableTo.difference(now).inDays;
                        return isExpired
                            ? Text(l.expired, style: TextStyle(fontSize: 12, color: c.textHint))
                            : Row(children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('$days ${l.days}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                              ]);
                      }),
                      const SizedBox(width: 8),
                      _ReportIconButton(capacity: capacity),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(capacity.autoTitle(l), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary)),
                  const SizedBox(height: 6),
                  Text(capacity.description, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.business_outlined, size: 14, color: c.textHint),
                      const SizedBox(width: 4),
                      Text(capacity.companyName, style: TextStyle(fontSize: 12, color: c.textHint)),
                      const SizedBox(width: 6),
                      CompanyRatingBadge(companyId: capacity.companyId, starSize: 11, fontSize: 11),
                      const SizedBox(width: 16),
                      Icon(Icons.location_on_outlined, size: 14, color: c.textHint),
                      const SizedBox(width: 4),
                      Text(capacity.location, style: TextStyle(fontSize: 12, color: c.textHint)),
                      const SizedBox(width: 16),
                      Icon(Icons.people_outline, size: 14, color: c.textHint),
                      const SizedBox(width: 4),
                      Text('${capacity.workerCount} ${l.persons}', style: TextStyle(fontSize: 12, color: c.textHint)),
                    ],
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

// ─── Report icon button ────────────────────────────────────────────────────────

class _ReportIconButton extends ConsumerWidget {
  final CapacityModel capacity;
  const _ReportIconButton({required this.capacity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.reportTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showReportDialog(context, ref, capacity),
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.flag_outlined, size: 15, color: c.textTertiary)),
      ),
    );
  }
}

// ─── Report dialog ─────────────────────────────────────────────────────────────

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
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
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

                    // Reason options
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

                    // Action buttons
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
