import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

const _localeKey = 'locale';

// See theme_provider.dart for why this talks to localStorage directly
// instead of going through shared_preferences.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    try {
      final saved = web.window.localStorage.getItem(_localeKey);
      if (saved != null && saved.isNotEmpty) return Locale(saved);
    } catch (_) {}
    return const Locale('de');
  }

  void setLocale(Locale locale) {
    state = locale;
    try {
      web.window.localStorage.setItem(_localeKey, locale.languageCode);
    } catch (_) {}
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
