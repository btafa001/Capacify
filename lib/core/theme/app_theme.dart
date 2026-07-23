import 'package:flutter/material.dart';

// ─── Brand / status colors — never change between themes ──────────────────────
class AppColors {
  // Brand
  static const Color primary        = Color(0xFFFF6B00);
  static const Color primaryDark    = Color(0xFFCC5500);
  // WCAG-accessible orange for SMALL text/icons on light backgrounds. The
  // brand #FF6B00 is only ~3.4:1 on white (fails AA 4.5:1 for normal text);
  // #C2410C is ~5.2:1. Use `primary` for large text (≥18.66px bold) and for
  // fills with white text on top; use this for small orange text/links/icons
  // sitting directly on a light surface.
  static const Color primaryAccessible = Color(0xFFC2410C);
  static const Color accent         = Color(0xFFFFC107);
  // Status
  static const Color live           = Color(0xFF2ECC71);
  static const Color urgent         = Color(0xFFFF3B30);
  static const Color distance       = Color(0xFF64B5F6);
  static const Color success        = Color(0xFF2ECC71);
  static const Color error          = Color(0xFFFF3B30);
  static const Color warning        = Color(0xFFFFC107);
  // Semantic
  static const Color offerColor     = Color(0xFF2ECC71);
  static const Color needColor      = Color(0xFFFF6B00);

  // ── Dark-theme static fallbacks (for const expressions / default) ──────────
  static const Color background     = Color(0xFF0A0E27);
  static const Color surface        = Color(0xFF121212);
  static const Color surfaceVariant = Color(0xFF1A1F3A);
  static const Color textPrimary    = Color(0xFFFFFFFF);
  static const Color textSecondary  = Color(0xFFA0A0A0);
  static const Color textTertiary   = Color(0xFF606060);
  static const Color textHint       = Color(0xFF9E9E9E);
  static const Color border         = Color(0xFF2A2A2A);

  // ── Context-aware accessor — use this in build() methods ──────────────────
  static _AppColorScheme of(BuildContext context) => _AppColorScheme(context);
}

class _AppColorScheme {
  final BuildContext _ctx;
  const _AppColorScheme(this._ctx);

  bool get _dark => Theme.of(_ctx).brightness == Brightness.dark;

  Color get background     => _dark ? const Color(0xFF0A0E27) : const Color(0xFFF5F6FA);
  Color get surface        => _dark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
  Color get surfaceVariant => _dark ? const Color(0xFF1A1F3A) : const Color(0xFFEEF0F8);
  Color get textPrimary    => _dark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A2E);
  Color get textSecondary  => _dark ? const Color(0xFFA0A0A0) : const Color(0xFF555570);
  // Light-mode values were #888899 (~3.5:1 on white) and #AAAAAA (~2.3:1) —
  // both fail WCAG AA's 4.5:1 for normal text. Darkened to ~5.0:1 / ~4.8:1
  // respectively, keeping textHint the lighter of the two (visual hierarchy
  // vs textTertiary) while both now clear AA on white and on surfaceVariant.
  Color get textTertiary   => _dark ? const Color(0xFF606060)  : const Color(0xFF6E6E82);
  Color get textHint       => _dark ? const Color(0xFF9E9E9E)  : const Color(0xFF707084);
  Color get border         => _dark ? const Color(0xFF2A2A2A)  : const Color(0xFFE0E0E8);
}

// ─── Theme provider state ──────────────────────────────────────────────────────
// Placed here for easy import alongside AppColors.

// ─── ThemeData factory ────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg        = isDark ? const Color(0xFF0A0E27) : const Color(0xFFF5F6FA);
    final surface   = isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final onSurface = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A2E);
    final secondary = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF555570);
    final border    = isDark ? const Color(0xFF2A2A2A)  : const Color(0xFFE0E0E8);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      // Inter for everything, from the bundled assets (see pubspec.yaml).
      // Set here rather than per-style: ThemeData applies `fontFamily` to the
      // whole DEFAULT text theme and only then merges `textTheme` on top, so
      // the nine styles overridden below AND the six that aren't all come out
      // Inter. Overriding only the listed ones (the old
      // GoogleFonts.interTextTheme call) would have left the rest on Roboto.
      fontFamily: 'Inter',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.black,
        error: AppColors.error,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),

      textTheme: TextTheme(
        displayLarge:  TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: onSurface, letterSpacing: -0.8),
        displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: onSurface, letterSpacing: -0.5),
        titleLarge:    TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: onSurface, letterSpacing: -0.3),
        titleMedium:   TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: onSurface),
        bodyLarge:     TextStyle(fontSize: 17, color: onSurface, height: 1.5),
        bodyMedium:    TextStyle(fontSize: 15, color: secondary, height: 1.5),
        bodySmall:     TextStyle(fontSize: 13, color: secondary),
        labelLarge:    TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: 0.3),
        labelMedium:   TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: isDark ? const Color(0xFF606060) : const Color(0xFF6E6E82), fontSize: 15),
        labelStyle: TextStyle(color: secondary, fontSize: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Small orange label on a light surface fails AA at #FF6B00 → use the
          // accessible orange in light mode (border can stay brand at 3:1).
          foregroundColor: isDark ? AppColors.primary : AppColors.primaryAccessible,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.primary : AppColors.primaryAccessible,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: onSurface),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),

      drawerTheme: DrawerThemeData(backgroundColor: surface),
    );
  }
}
