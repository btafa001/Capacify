import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A short-lived, isolated Firebase session used during admin-assisted
/// onboarding.
///
/// The problem it solves: the client SDK's `createUserWithEmailAndPassword`
/// automatically signs you in AS the newly created account, which would sign
/// the admin out of their own session mid-onboarding. By doing that creation
/// through a *separate* named `FirebaseApp` instance (same project, its own
/// auth/firestore session), the admin's primary `Firebase.app()` session is
/// never touched.
///
/// It's deliberately NOT a Riverpod service — it's a plain object created
/// fresh for one onboarding step, used, then disposed. Never reuse a single
/// instance across two onboardings; create a new one each time.
class SecondaryFirebaseSession {
  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  Future<void> start() async {
    // The name MUST be unique per invocation — never a fixed constant.
    // If a previous session's dispose() didn't run (e.g. a browser refresh
    // mid-flow), a fixed name would make the next Firebase.initializeApp throw
    // 'duplicate-app'. A timestamp suffix sidesteps that entirely, which is
    // what makes back-to-back onboardings in one admin sitting safe.
    final name = 'admin_onboarding_${DateTime.now().microsecondsSinceEpoch}';
    _app = await Firebase.initializeApp(
      name: name,
      options: Firebase.app().options, // same project (capacify-mvp), separate session slot
    );
    _auth = FirebaseAuth.instanceFor(app: _app!);
    _firestore = FirebaseFirestore.instanceFor(app: _app!);
  }

  FirebaseAuth get auth => _auth!;
  FirebaseFirestore get firestore => _firestore!;

  /// Signs out and tears down the isolated app slot. Each step wrapped in its
  /// own try/catch so a failure in one never prevents the other — disposal
  /// must be best-effort and total, since this is what guarantees no leaked
  /// throwaway auth state survives the onboarding step.
  Future<void> dispose() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
    try {
      await _app?.delete();
    } catch (_) {}
    _app = null;
    _auth = null;
    _firestore = null;
  }
}
