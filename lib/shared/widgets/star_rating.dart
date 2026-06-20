import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/company_provider.dart';

/// Read-only star row for an average rating (supports half stars).
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;

  const StarRatingDisplay({super.key, required this.rating, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? AppColors.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final threshold = i + 1;
        IconData icon;
        if (rating >= threshold) {
          icon = Icons.star;
        } else if (rating >= threshold - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: starColor);
      }),
    );
  }
}

/// Tappable 1-5 star picker for submitting a rating.
class StarRatingInput extends StatelessWidget {
  final int value;
  final double size;
  final ValueChanged<int> onChanged;

  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        return GestureDetector(
          onTap: () => onChanged(starValue),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              starValue <= value ? Icons.star : Icons.star_border,
              size: size,
              color: AppColors.accent,
            ),
          ),
        );
      }),
    );
  }
}

/// Compact "★ 4.2 (13)" badge for inline display next to a company name.
/// Renders nothing while loading or if the company has no ratings yet.
class CompanyRatingBadge extends ConsumerWidget {
  final String companyId;
  final double starSize;
  final double fontSize;

  const CompanyRatingBadge({super.key, required this.companyId, this.starSize = 12, this.fontSize = 11});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final companyAsync = ref.watch(companyByIdProvider(companyId));
    return companyAsync.maybeWhen(
      data: (company) {
        if (company == null || company.ratingCount == 0) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: starSize, color: AppColors.accent),
            const SizedBox(width: 2),
            Text(
              company.avgRating.toStringAsFixed(1),
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: c.textSecondary),
            ),
            const SizedBox(width: 2),
            Text(
              '(${company.ratingCount})',
              style: TextStyle(fontSize: fontSize, color: c.textTertiary),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
