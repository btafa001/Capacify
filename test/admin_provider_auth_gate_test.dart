// Regression tests for the "Dazu haben Sie keine Berechtigung." bug. Every
// admin-only query can pass firestore.rules only via isAdmin(), yet these
// listeners used to open on ANY account — the dashboard watches several for
// badge counts — so every ordinary session fired a query the rules could only
// deny. A denied Firestore listener terminates and Riverpod caches the
// AsyncError, so that denial then stuck until a full page reload.
//
// Firebase is deliberately NOT initialized here. That is what makes these tests
// meaningful: AdminService holds `FirebaseFirestore.instance`, so if a provider
// ever reaches Firestore it throws (see the third test, which pins that). A
// provider that returns cleanly therefore proves the gate short-circuited
// before any listener was created.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capacify/core/services/admin_provider.dart';
import 'package:capacify/core/services/auth_provider.dart';
import 'package:capacify/core/utils/listener_diagnostics.dart';

ProviderContainer _signedOutContainer() {
  final container = ProviderContainer(overrides: [
    authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// A signed-in but NON-admin session — the case that was actually firing denied
/// admin queries in production. isAdminProvider is overridden directly because
/// resolving it for real would need Firestore.
ProviderContainer _nonAdminContainer() {
  final container = ProviderContainer(overrides: [
    isAdminProvider.overrideWith((ref) => Stream.value(false)),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Subscribes before awaiting: a StreamProvider that nothing listens to stays
/// in AsyncLoading forever, so a bare `read(...future)` would just time out.
Future<T> _resolve<T>(ProviderContainer container, ProviderListenable<AsyncValue<T>> provider,
    Future<T> Function() future) async {
  final sub = container.listen(provider, (_, __) {});
  addTearDown(sub.close);
  return future();
}

void main() {
  test('admin listeners stay off Firestore while signed out', () async {
    final c = _signedOutContainer();

    expect(await _resolve(c, pendingRatingsProvider, () => c.read(pendingRatingsProvider.future)), isEmpty);
    expect(await _resolve(c, pendingCompaniesProvider, () => c.read(pendingCompaniesProvider.future)), isEmpty);
    expect(await _resolve(c, allCompaniesAdminProvider, () => c.read(allCompaniesAdminProvider.future)), isEmpty);
    expect(await _resolve(c, flaggedCapacitiesProvider, () => c.read(flaggedCapacitiesProvider.future)), isEmpty);
    expect(await _resolve(c, flaggedCompaniesProvider, () => c.read(flaggedCompaniesProvider.future)), isEmpty);
    expect(await _resolve(c, allReportsProvider, () => c.read(allReportsProvider.future)), isEmpty);
    expect(await _resolve(c, capacityOwnerMapProvider, () => c.read(capacityOwnerMapProvider.future)), isEmpty);
  });

  test('signed out is an empty result, never an error state', () async {
    final c = _signedOutContainer();

    await _resolve(c, pendingRatingsProvider, () => c.read(pendingRatingsProvider.future));
    // hasError would put the screen straight back into the dead-end state this
    // whole fix is about — signed-out must read as "nothing", not "denied".
    expect(c.read(pendingRatingsProvider).hasError, isFalse);
  });

  test('a signed-in NON-admin never opens an admin listener', () async {
    // The regression that was still live after the first fix: a plain signed-in
    // gate let every ordinary account fire pendingRatings, which the rules can
    // only deny. Reaching Firestore here would throw, so an empty result is
    // proof the query was never sent.
    final c = _nonAdminContainer();

    expect(await _resolve(c, pendingRatingsProvider, () => c.read(pendingRatingsProvider.future)), isEmpty);
    expect(await _resolve(c, allReportsProvider, () => c.read(allReportsProvider.future)), isEmpty);
    expect(await _resolve(c, capacityOwnerMapProvider, () => c.read(capacityOwnerMapProvider.future)), isEmpty);
    expect(c.read(pendingRatingsProvider).hasError, isFalse);
  });

  test('reaching Firestore in this environment really does throw', () {
    // Pins the assumption the tests above rest on: without Firebase.initializeApp
    // constructing AdminService blows up. So the empty results above cannot be a
    // Firestore call that quietly returned nothing.
    final container = _signedOutContainer();
    expect(() => container.read(adminServiceProvider), throwsA(anything));
  });

  test('the denial logger re-emits errors instead of swallowing them', () async {
    // If the diagnostic transformer ate the error, every denied screen would
    // hang on its spinner forever rather than showing the retryable state.
    final controller = StreamController<int>();
    final seen = <Object>[];
    controller.stream
        .logPermissionDenials('test')
        .listen((_) {}, onError: seen.add);

    controller.addError(StateError('boom'));
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single, isA<StateError>());
    await controller.close();
  });
}
