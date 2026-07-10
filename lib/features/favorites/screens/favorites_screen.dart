import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/capacity_model.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/services/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../opportunities/screens/capacity_detail_screen.dart';
import '../../../core/services/analytics_service.dart';

class FavoritesScreen extends ConsumerWidget {
  final bool embedded;
  const FavoritesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) => AnalyticsService.logScreenView('Favorites'));
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final favoritesAsync = ref.watch(userFavoriteCapacitiesProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: c.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          l.navFavorites,
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: favoritesAsync.when(
        data: (capacities) {
          if (capacities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_outline, size: 72, color: c.textTertiary),
                  const SizedBox(height: 20),
                  Text(
                    l.noFavoritesYet,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.tapHeartToSaveHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: c.textTertiary, height: 1.5),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Stats bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    _StatDot(
                      count: capacities.where((cap) => cap.type == CapacityType.offer).length,
                      label: l.statsAvailable,
                      color: AppColors.offerColor,
                    ),
                    const SizedBox(width: 16),
                    _StatDot(
                      count: capacities.where((cap) => cap.type == CapacityType.need).length,
                      label: l.statsNeeded,
                      color: AppColors.needColor,
                    ),
                    const Spacer(),
                    Text(
                      l.totalLabel(capacities.length),
                      style: TextStyle(fontSize: 12, color: c.textTertiary),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 16, bottom: 80),
                  itemCount: capacities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _FavoriteCard(capacity: capacities[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(l.errorWithMessage(e), style: const TextStyle(color: AppColors.error))),
      ),
    );
  }
}

// ─── Stat dot ───────────────────────────────────────────────────────────────

class _StatDot extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatDot({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$count $label', style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Card ────────────────────────────────────────────────────────────────────

class _FavoriteCard extends ConsumerWidget {
  final CapacityModel capacity;

  const _FavoriteCard({required this.capacity});

  Color get _accentColor =>
      capacity.type == CapacityType.offer ? AppColors.offerColor : AppColors.needColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => showCapacityDetailDialog(context, capacity),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentColor.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left color strip
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(color: _accentColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          capacity.typeLabel(l),
                          style: TextStyle(color: _accentColor, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Trade
                      Text(l.tradeName(capacity.trade), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      const Spacer(),
                      Text(
                        capacity.timePostedLabel(l),
                        style: TextStyle(fontSize: 11, color: c.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    capacity.autoTitle(l),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: c.textTertiary),
                      const SizedBox(width: 3),
                      Text(capacity.location, style: TextStyle(fontSize: 11, color: c.textTertiary)),
                      const SizedBox(width: 12),
                      Icon(Icons.people_outline, size: 12, color: c.textTertiary),
                      const SizedBox(width: 3),
                      Text('${capacity.workerCount} ${l.persPeriod}', style: TextStyle(fontSize: 11, color: c.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),

            // Unfavorite button
            IconButton(
              onPressed: () async {
                final user = ref.read(authStateProvider).value;
                if (user != null) {
                  await ref.read(capacityServiceProvider).toggleFavorite(
                    capacityId: capacity.id,
                    userId: user.uid,
                  );
                }
              },
              icon: const Icon(Icons.favorite, color: AppColors.primary, size: 20),
              tooltip: l.removeFavoriteTooltip,
            ),
          ],
        ),
      ),
    );
  }
}
