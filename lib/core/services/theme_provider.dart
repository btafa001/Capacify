import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

const _themeModeKey = 'theme_mode';

// Reads/writes browser localStorage directly via JS interop — synchronous,
// no plugin/platform-channel layer involved. shared_preferences was tried
// here first, but its async initialization hangs indefinitely under
// `flutter build web --release` specifically (works fine in debug/profile),
// which silently broke persistence on the deployed site while still
// appearing to work during local development.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      if (web.window.localStorage.getItem(_themeModeKey) == 'dark') {
        return ThemeMode.dark;
      }
    } catch (_) {
      // Storage unavailable (e.g. blocked by browser privacy settings) —
      // fall through to the default.
    }
    return ThemeMode.light;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    try {
      web.window.localStorage.setItem(
        _themeModeKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
