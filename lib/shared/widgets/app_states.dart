import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

/// Shared, consistent loading / empty / error states so screens stop shipping
/// bare spinners and raw exception text. Dependency-free (no shimmer package):
/// the skeleton uses a slow opacity pulse.

/// A pulsing grey block — the skeleton primitive.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_ctrl),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Skeleton placeholder for the capacity feed — a few card-shaped shells while
/// the first realtime snapshot loads.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      itemCount: 5,
      itemBuilder: (_, __) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(children: [
                    SkeletonBox(width: 70, height: 20),
                    SizedBox(width: 8),
                    SkeletonBox(width: 44, height: 20),
                    Spacer(),
                    SkeletonBox(width: 40, height: 14),
                  ]),
                  SizedBox(height: 14),
                  SkeletonBox(width: 240, height: 20),
                  SizedBox(height: 8),
                  SkeletonBox(width: 160, height: 14),
                  SizedBox(height: 16),
                  Row(children: [
                    SkeletonBox(width: 80, height: 26),
                    SizedBox(width: 6),
                    SkeletonBox(width: 90, height: 26),
                    SizedBox(width: 6),
                    SkeletonBox(width: 70, height: 26),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Friendly error panel with a retry button — never shows raw exception text
/// (AppLocalizations.errorWithMessage already maps to a safe message).
class AppErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const AppErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.cloud_off_outlined, size: 30, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(l.errorWithMessage(error),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.retryButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Illustrated empty state with an optional call-to-action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: c.textTertiary, height: 1.5)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
