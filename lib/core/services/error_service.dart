import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../constants/app_constants.dart';

/// Lightweight production crash reporting (M6).
///
/// There is no Crashlytics/Sentry wired up — Sentry needs a DSN and an account
/// that don't exist yet — so until then, UNCAUGHT errors (the ones that
/// actually break a screen and would otherwise be completely invisible on a
/// user's machine) are appended to a write-only Firestore `clientErrors`
/// collection the founder can triage from the console. See firestore.rules:
/// create-only, shape-pinned, gated by App Check; nobody reads it in-app.
///
/// Scope is deliberately just the two global hooks below. The many intentional
/// best-effort `catch (_) {}` swallows in the service layer are NOT rerouted
/// here — they're expected and would only add noise. Call [reportError]
/// explicitly from a catch block only when a failure there is genuinely
/// unexpected and worth seeing.
///
/// To graduate to Sentry later: add `sentry_flutter`, create a project for its
/// DSN, and forward [reportError] (plus the two hooks) to `Sentry.captureX`.
class ErrorService {
  ErrorService._();

  static bool _installed = false;
  static bool _reporting = false; // re-entrancy guard (see reportError)
  static int _sent = 0;
  static const int _maxPerSession = 50;
  static String? _lastSignature;

  /// Installs the global Flutter + platform error hooks. Call once, as early in
  /// `main` as possible (before runApp). The default console presentation is
  /// preserved on top of the forwarding, so debugging is unaffected.
  static void init() {
    if (_installed) return;
    _installed = true;

    FlutterError.onError = (FlutterErrorDetails details) {
      // Keep Flutter's default dump (red screen in debug, console in profile).
      FlutterError.presentError(details);
      reportError(
        details.exception,
        details.stack,
        context: details.context?.toString() ?? 'FlutterError',
      );
    };

    // Uncaught async / zone errors — Flutter routes these here since 3.3, so no
    // runZonedGuarded wrapper is needed. Returning true marks them handled.
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) debugPrint('Uncaught (async): $error\n$stack');
      reportError(error, stack, context: 'PlatformDispatcher');
      return true;
    };
  }

  /// Appends one error to `clientErrors`, best-effort. Never throws, never
  /// blocks the caller on the result, and never reports an error raised BY the
  /// reporting write itself (the [_reporting] guard stops a permission-denied
  /// write from looping). Throttled per session and de-duplicated against the
  /// immediately preceding error so a tight failing loop can't flood Firestore.
  static Future<void> reportError(
    Object error,
    StackTrace? stack, {
    String? context,
  }) async {
    if (_reporting || _sent >= _maxPerSession) return;

    final message = error.toString();
    final signature = '$context::$message';
    if (signature == _lastSignature) return; // collapse identical repeats
    _lastSignature = signature;

    _reporting = true;
    try {
      _sent++;
      String uid = '';
      try {
        uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      } catch (_) {}
      await FirebaseFirestore.instance.collection('clientErrors').add({
        'message': _cap(message, 2000),
        'stack': _cap(stack?.toString() ?? '', 8000),
        'context': _cap(context ?? '', 200),
        'uid': uid,
        'url': _cap(_safe(() => web.window.location.href), 500),
        'userAgent': _cap(_safe(() => web.window.navigator.userAgent), 500),
        'appVersion': kAppVersion,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A failed crash report must never itself crash or loop. Swallow.
    } finally {
      _reporting = false;
    }
  }

  static String _cap(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  static String _safe(String Function() f) {
    try {
      return f();
    } catch (_) {
      return '';
    }
  }
}
