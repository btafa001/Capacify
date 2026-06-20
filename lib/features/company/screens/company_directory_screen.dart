import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/services/company_provider.dart';
import '../../../shared/widgets/capacify_logo.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../../core/localization/app_localizations.dart';
import 'company_detail_screen.dart';

const List<String> kAllTrades = [
  'Alle Gewerke',
  'Generalunternehmer',
  'Rohbau',
  'Trockenbau',
  'Elektro',
  'Sanitär & Heizung',
  'Dach',
  'Fassade',
  'Tiefbau',
  'Architektur',
  'Statik',
  'Stahl',
  'Beton',
  'HVAC',
  'Lieferant',
];

class CompanyDirectoryScreen extends ConsumerStatefulWidget {
  const CompanyDirectoryScreen({super.key});

  @override
  ConsumerState<CompanyDirectoryScreen> createState() =>
      _CompanyDirectoryScreenState();
}

class _CompanyDirectoryScreenState
    extends ConsumerState<CompanyDirectoryScreen> {
  String _searchText = '';
  String _selectedTrade = 'Alle Gewerke';
  bool _onlyVerified = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CompanyModel> _filterCompanies(List<CompanyModel> companies) {
    return companies.where((c) {
      if (_onlyVerified && !c.isVerified) return false;
      if (_selectedTrade != 'Alle Gewerke' && c.trade != _selectedTrade) return false;
      if (_searchText.isNotEmpty) {
        final q = _searchText.toLowerCase();
        return c.name.toLowerCase().contains(q) ||
            c.city.toLowerCase().contains(q) ||
            c.trade.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final companiesAsync = ref.watch(companiesProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: CapacifyWordmark(symbolSize: 28, fontSize: 18, textColor: c.textPrimary),
        actions: [
          companiesAsync.maybeWhen(
            data: (companies) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Text(l.companiesCountBadge(companies.length), style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            orElse: () => const SizedBox(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(color: c.border, height: 0.5),
        ),
      ),
      body: Column(
        children: [
          // ── HEADER ──
          Container(
            color: c.surface,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  l.navCompanies,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  l.directorySubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── SEARCH + FILTERS ──
          Container(
            color: c.surface,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: c.textPrimary, fontSize: 15),
                  onChanged: (v) => setState(() => _searchText = v),
                  decoration: InputDecoration(
                    hintText: l.directorySearchHint,
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, color: c.textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchText = '');
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
                        label: l.onlyVerifiedFilter,
                        icon: Icons.verified,
                        isActive: _onlyVerified,
                        activeColor: AppColors.live,
                        onTap: () => setState(() => _onlyVerified = !_onlyVerified),
                      ),
                      const SizedBox(width: 8),
                      _TradePillDropdown(
                        selected: _selectedTrade,
                        onChanged: (v) => setState(() => _selectedTrade = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── COMPANY LIST ──
          Expanded(
            child: companiesAsync.when(
              data: (companies) {
                final filtered = _filterCompanies(companies);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.business_outlined, size: 40, color: AppColors.primary),
                        ),
                        const SizedBox(height: 20),
                        Text(l.noCompaniesFound, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textSecondary)),
                        const SizedBox(height: 8),
                        Text(l.adjustFiltersText, style: TextStyle(fontSize: 14, color: c.textTertiary)),
                      ],
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 260,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _CompanyCard(company: filtered[index]),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text(l.errorWithMessage(e), style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PILL TOGGLE ────────────────────────────────────

class _PillToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _PillToggle({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
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
          color: isActive ? activeColor : c.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? activeColor : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? Colors.white : c.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? Colors.white : c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TRADE PILL DROPDOWN ────────────────────────────

class _TradePillDropdown extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;

  const _TradePillDropdown({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isActive = selected != 'Alle Gewerke';
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: c.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) {
            final cc = AppColors.of(ctx);
            final cl = AppLocalizations.of(ctx);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cc.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 8),
                ...kAllTrades.map((t) => ListTile(
                  title: Text(t == 'Alle Gewerke' ? cl.tradeAll : cl.tradeName(t), style: TextStyle(color: cc.textPrimary, fontSize: 16)),
                  trailing: selected == t ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () { onChanged(t); Navigator.pop(ctx); },
                )),
                const SizedBox(height: 16),
              ],
            );
          },
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
            Icon(Icons.build_outlined, size: 15, color: isActive ? AppColors.primary : c.textSecondary),
            const SizedBox(width: 7),
            Text(
              isActive ? selected : l.tradeFilterLabel,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? AppColors.primary : c.textSecondary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 15, color: isActive ? AppColors.primary : c.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── COMPANY CARD ───────────────────────────────────

class _CompanyCard extends StatefulWidget {
  final CompanyModel company;
  const _CompanyCard({required this.company});

  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final company = widget.company;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: company)),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? AppColors.primary.withOpacity(0.4) : c.border,
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, color: AppColors.primary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + verification badge
                        Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  company.name.isNotEmpty ? company.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const Spacer(),
                            _VerificationBadge(status: company.verificationStatus),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Name
                        Text(
                          company.name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        CompanyRatingBadge(companyId: company.id),
                        const SizedBox(height: 4),

                        // Location + employees
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 12, color: c.textTertiary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                company.city.isNotEmpty ? company.city : '—',
                                style: TextStyle(fontSize: 12, color: c.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.people_outline, size: 12, color: c.textTertiary),
                            const SizedBox(width: 3),
                            Text('${company.employees}', style: TextStyle(fontSize: 12, color: c.textTertiary)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Trade badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          ),
                          child: Text(
                            l.tradeName(company.trade),
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Description
                        if (company.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              company.description,
                              style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                      ],
                    ),
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

// ─── VERIFICATION BADGE ──────────────────────────────

class _VerificationBadge extends StatelessWidget {
  final String status;
  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final IconData icon;
    final String label;
    final Color color;
    final bool filled;
    switch (status) {
      case 'verified':
        icon = Icons.verified;
        label = l.verifiedLabel;
        color = AppColors.live;
        filled = true;
        break;
      case 'pending':
        icon = Icons.schedule;
        label = l.verificationPendingBadge;
        color = AppColors.accent;
        filled = true;
        break;
      default:
        icon = Icons.how_to_reg;
        label = l.registeredBadge;
        color = c.textTertiary;
        filled = false;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.10) : null,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: filled ? color.withOpacity(0.30) : color.withOpacity(0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}
