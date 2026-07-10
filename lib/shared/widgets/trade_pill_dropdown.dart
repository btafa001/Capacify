import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';

/// Pill button that opens a bottom sheet for selecting up to 2 trades —
/// shared between the company directory and the live feed filters so both
/// behave identically.
class TradePillDropdown extends StatelessWidget {
  final List<String> selected;
  final Function(List<String>) onChanged;

  const TradePillDropdown({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isActive = selected.isNotEmpty;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: c.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) {
            final cc = AppColors.of(ctx);
            final cl = AppLocalizations.of(ctx);
            final tempSelected = List<String>.from(selected);
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: cc.border, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 8),
                      Text(cl.maxTwoTradesNotice, style: TextStyle(color: cc.textTertiary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: kTrades.map((t) {
                              final isChecked = tempSelected.contains(t);
                              final atLimit = tempSelected.length >= 2 && !isChecked;
                              return CheckboxListTile(
                                title: Text(
                                  cl.tradeName(t),
                                  style: TextStyle(color: atLimit ? cc.textTertiary : cc.textPrimary, fontSize: 16),
                                ),
                                value: isChecked,
                                activeColor: AppColors.primary,
                                onChanged: atLimit
                                    ? null
                                    : (checked) {
                                        setSheetState(() {
                                          if (checked == true) {
                                            tempSelected.add(t);
                                          } else {
                                            tempSelected.remove(t);
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              onChanged(tempSelected);
                              Navigator.pop(ctx);
                            },
                            child: Text(cl.applyFilterButton),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
              isActive ? selected.map((t) => l.tradeName(t)).join(', ') : l.tradeFilterLabel,
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
