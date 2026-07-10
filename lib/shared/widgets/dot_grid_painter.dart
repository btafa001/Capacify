import 'package:flutter/material.dart';

/// Subtle dot-grid background used behind hero/feed sections.
/// Pass a theme-aware color (e.g. `AppColors.of(context).textPrimary`) so the
/// dots stay visible in both light and dark themes.
class DotGridPainter extends CustomPainter {
  final Color color;
  const DotGridPainter({required this.color});

  static const spacing = 28.0;
  static const radius = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(0.09);
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter old) => old.color != color;
}
