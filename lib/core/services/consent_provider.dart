import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import 'analytics_service.dart';

/// Cookie/analytics consent state, persisted in localStorage (same JS-interop
/// pattern as theme/locale — shared_preferences hangs under release web).
///
/// - null      → not decided yet (show the banner, analytics stays OFF)
/// - 'granted' → user opted in (analytics ON)
/// - 'denied'  → user opted out (analytics OFF)
///
/// Privacy-first default: until an explicit "granted", nothing is collected.
const _consentKey = 'analytics_consent';

enum ConsentState { undecided, granted, denied }

class ConsentNotifier extends Notifier<ConsentState> {
  @override
  ConsentState build() {
    ConsentState initial = ConsentState.undecided;
    try {
      final v = web.window.localStorage.getItem(_consentKey);
      if (v == 'granted') initial = ConsentState.granted;
      if (v == 'denied') initial = ConsentState.denied;
    } catch (_) {}
    // Apply the persisted choice to the analytics SDK on startup.
    AnalyticsService.applyConsent(initial == ConsentState.granted);
    return initial;
  }

  void grant() => _set(ConsentState.granted);
  void deny() => _set(ConsentState.denied);

  void _set(ConsentState s) {
    state = s;
    try {
      web.window.localStorage
          .setItem(_consentKey, s == ConsentState.granted ? 'granted' : 'denied');
    } catch (_) {}
    AnalyticsService.applyConsent(s == ConsentState.granted);
  }
}

final consentProvider =
    NotifierProvider<ConsentNotifier, ConsentState>(ConsentNotifier.new);
