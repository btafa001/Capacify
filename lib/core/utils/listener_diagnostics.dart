import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Why this exists: a Firestore `snapshots()` listener that is denied by the
/// rules TERMINATES — the SDK never retries it — and a Riverpod StreamProvider
/// then caches that AsyncError for the life of the ProviderContainer. So a
/// single transient denial bricks a screen ("Dazu haben Sie keine
/// Berechtigung.") until a full page reload, which is exactly the symptom that
/// was reported for the admin ratings queue and Erhaltene Anfragen.
///
/// The providers are now gated on auth so the listener can't start before
/// `request.auth` exists, but a denial can still in principle arrive later
/// (e.g. around an ID-token refresh). This logs the ONE fact that tells the two
/// causes apart: was there a signed-in user at the moment the denial arrived?
///
///   * `authed=false` → the listener outran auth (startup race).
///   * `authed=true`  → auth was live, so it's a token/rules-evaluation issue,
///     and `sinceStart` says whether it lands near the ~1h token refresh.
///
/// Purely observational — the error is always re-emitted, never swallowed, so
/// the UI still shows its (now retryable) error state.
extension ListenerDiagnostics<T> on Stream<T> {
  Stream<T> logPermissionDenials(String label) {
    return transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stack, sink) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            final user = FirebaseAuth.instance.currentUser;
            final since = DateTime.now().difference(_appStart);
            debugPrint(
              '[listener-denied] $label '
              'authed=${user != null} '
              'uid=${user?.uid ?? '-'} '
              'emailVerified=${user?.emailVerified ?? false} '
              'sinceStart=${since.inSeconds}s',
            );
          }
          sink.addError(error, stack);
        },
      ),
    );
  }
}

final DateTime _appStart = DateTime.now();
