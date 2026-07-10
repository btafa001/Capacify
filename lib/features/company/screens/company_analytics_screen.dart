import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/company_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';

class CompanyAnalyticsScreen extends ConsumerWidget {
  final CompanyModel company;

  const CompanyAnalyticsScreen({
    super.key,
    required this.company,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('CompanyAnalytics'));
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: c.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.companyAnalyticsTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        AppColors.primary.withOpacity(0.15),
                    child: Text(
                      company.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          company.trades.map((t) => l.tradeName(t)).join(', '),
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Key Metrics
            Text(
              l.keyMetricsTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final metrics = [
                  _MetricCard(
                    icon: Icons.visibility_outlined,
                    label: l.profileViewsLabel,
                    value: '24',
                    color: AppColors.primary,
                    trend: l.plusThisWeek(3),
                  ),
                  _MetricCard(
                    icon: Icons.people_outline,
                    label: l.interestedPartiesLabel,
                    value: '8',
                    color: AppColors.success,
                    trend: l.plusThisWeek(1),
                  ),
                  _MetricCard(
                    icon: Icons.volunteer_activism_outlined,
                    label: l.activeCapacitiesLabel,
                    value: '3',
                    color: AppColors.accent,
                    trend: l.allActiveText,
                  ),
                ];

                return isNarrow
                    ? Column(
                        children: metrics
                            .map((m) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 12),
                                  child: m,
                                ))
                            .toList(),
                      )
                    : Row(
                        children: metrics
                            .map((m) => Expanded(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(
                                            right: 12),
                                    child: m,
                                  ),
                                ))
                            .toList(),
                      );
              },
            ),

            const SizedBox(height: 32),

            // Recent Activity
            Text(
              l.recentActivityTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            _ActivityItem(
              icon: Icons.check_circle_outlined,
              title: l.profileUpdatedText,
              time: l.daysAgoFull(2),
              color: AppColors.success,
            ),
            _ActivityItem(
              icon: Icons.mail_outlined,
              title: l.newRequestReceivedText,
              time: l.daysAgoFull(5),
              color: AppColors.primary,
            ),
            _ActivityItem(
              icon: Icons.add_circle_outlined,
              title: l.capacityCreatedText,
              time: l.oneWeekAgoText,
              color: AppColors.accent,
            ),

            const SizedBox(height: 32),

            // Rating Section
            Text(
              l.ratingTrustTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.ratingLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Padding(
                                  padding:
                                      const EdgeInsets.only(
                                          right: 4),
                                  child: Icon(
                                    index < 4
                                        ? Icons.star
                                        : Icons.star_outline,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '4.0 ${l.ratingsCount(8)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textPrimary,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success
                              .withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.success
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          l.verifiedTitleCase,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.trustScoreText(92),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.92,
                      backgroundColor: c.border,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String trend;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trend,
            style: TextStyle(
              fontSize: 12,
              color: c.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}