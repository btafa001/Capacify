import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CapacifySymbol — the C-bracket mark, drawn by CustomPainter.
//
//  Arms are 26 % of the widget width. A white accent square sits inside
//  the upper-right area of the C opening, matching the brand spec.
// ─────────────────────────────────────────────────────────────────────────────

class CapacifySymbol extends StatelessWidget {
  final double size;
  final Color symbolColor;
  final Color accentColor;

  const CapacifySymbol({
    super.key,
    required this.size,
    this.symbolColor = AppColors.primary,
    this.accentColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SymbolPainter(
          symbolColor: symbolColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _SymbolPainter extends CustomPainter {
  final Color symbolColor;
  final Color accentColor;

  const _SymbolPainter(
      {required this.symbolColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = w * 0.26; // arm thickness

    final fill = Paint()
      ..color = symbolColor
      ..style = PaintingStyle.fill;
    final accent = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Left vertical bar (full height)
    canvas.drawRect(Rect.fromLTWH(0, 0, t, h), fill);
    // Top horizontal bar
    canvas.drawRect(Rect.fromLTWH(0, 0, w, t), fill);
    // Bottom horizontal bar
    canvas.drawRect(Rect.fromLTWH(0, h - t, w, t), fill);

    // White accent square — upper-right inner area of the C opening
    final sq = t * 0.58;
    canvas.drawRect(
      Rect.fromLTWH(w - sq - t * 0.22, t * 0.17, sq, sq),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) =>
      old.symbolColor != symbolColor || old.accentColor != accentColor;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CapacifyWordmark — symbol + styled "Capacify" text side by side.
//
//  The "C" in "Capacify" renders in [primaryColor] (orange by default);
//  "apacify" renders in [textColor] (white on dark, dark on light).
// ─────────────────────────────────────────────────────────────────────────────

class CapacifyWordmark extends StatelessWidget {
  final double symbolSize;
  final double fontSize;
  final Color symbolColor;
  final Color textColor;
  final Color accentColor;
  final Color? cLetterColor;

  const CapacifyWordmark({
    super.key,
    this.symbolSize = 36,
    this.fontSize = 22,
    this.symbolColor = AppColors.primary,
    this.textColor = AppColors.textPrimary,
    this.accentColor = Colors.white,
    this.cLetterColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CapacifySymbol(
          size: symbolSize,
          symbolColor: symbolColor,
          accentColor: accentColor,
        ),
        SizedBox(width: symbolSize * 0.28),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'C',
                style: TextStyle(
                  color: cLetterColor ?? textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'apacify',
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
