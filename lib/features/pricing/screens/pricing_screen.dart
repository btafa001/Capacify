import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/analytics_service.dart';

/// Plans & Vermittlungen pricing. During Early Access everyone is on 20 free
/// connections/month; the paid tiers are shown as "coming soon" so the value
/// metric (a reveal) and the eventual ladder are legible, without committing to
/// prices yet. Reached from the out-of-credits state and from Settings.
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('Pricing'));
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.pop(context)),
        title: Text(l.pricingTitle,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
            children: [
              // Early Access banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.rocket_launch_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.pricingEarlyAccessBadge,
                            style: const TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(l.pricingEarlyAccessBody(kEarlyAccessQuota),
                            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text(l.pricingPlansHeader,
                  style: TextStyle(color: c.textTertiary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
              const SizedBox(height: 12),

              _PlanCard(
                name: l.planFreeName,
                quota: l.planFreeQuota(kFreeQuota),
                price: l.planFreePrice,
                desc: l.planFreeDesc,
                isCurrent: kEarlyAccessMode,
                accent: c.textSecondary,
              ),
              const SizedBox(height: 12),
              _PlanCard(
                name: l.planProName,
                quota: l.planProQuota(kProQuota),
                price: l.planProPrice,
                desc: l.planProDesc,
                highlighted: true,
                comingSoon: true,
                accent: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _PlanCard(
                name: l.planPremiumName,
                quota: l.planPremiumQuota,
                price: l.planPremiumPrice,
                desc: l.planPremiumDesc,
                comingSoon: true,
                accent: AppColors.live,
              ),

              const SizedBox(height: 24),
              Text(l.pricingHowCreditsWork,
                  style: TextStyle(color: c.textTertiary, fontSize: 12.5, height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String quota;
  final String price;
  final String desc;
  final bool isCurrent;
  final bool highlighted;
  final bool comingSoon;
  final Color accent;

  const _PlanCard({
    required this.name,
    required this.quota,
    required this.price,
    required this.desc,
    required this.accent,
    this.isCurrent = false,
    this.highlighted = false,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlighted ? AppColors.primary.withOpacity(0.5) : c.border,
            width: highlighted ? 2 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(name, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(width: 10),
            if (isCurrent)
              _Tag(text: l.planCurrentLabel, color: AppColors.live)
            else if (comingSoon)
              _Tag(text: l.planComingSoon, color: c.textTertiary),
            const Spacer(),
            Text(price, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.toll_outlined, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(quota, style: TextStyle(color: c.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(color: c.textTertiary, fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
    );
  }
}
