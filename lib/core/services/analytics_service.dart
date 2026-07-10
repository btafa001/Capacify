import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics is OFF until the user grants consent (GDPR/TTDSG: non-essential
/// analytics needs prior opt-in). Nothing is logged and collection stays
/// disabled until [applyConsent(true)] is called from the consent flow. This
/// is enforced here at the single choke-point so every screen's log call is
/// automatically compliant without each caller having to check.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static bool _consented = false;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Called once at startup with the persisted choice, and again whenever the
  /// user changes it. Flips Firebase's own collection switch AND our local
  /// gate, so a denial both stops our logging and tells the SDK not to collect.
  static Future<void> applyConsent(bool granted) async {
    _consented = granted;
    try {
      await _analytics.setAnalyticsCollectionEnabled(granted);
    } catch (_) {}
  }

  static bool get hasConsent => _consented;

  static void logScreenView(String screenName) {
    if (!_consented) return;
    _analytics.logScreenView(screenName: screenName);
  }

  static void logEvent(String name, {Map<String, Object>? parameters}) {
    if (!_consented) return;
    _analytics.logEvent(name: name, parameters: parameters);
  }
}
