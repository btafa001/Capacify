import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company_model.dart';
import '../models/capacity_model.dart';
import '../models/capacity_owner_model.dart';
import 'secondary_firebase_app.dart';

/// Typed error so the UI layer can map onboarding failures to localized,
/// admin-flavored copy (rather than the service hardcoding strings). Carries
/// the underlying FirebaseAuth code so the wizard can special-case
/// 'email-already-in-use' distinctly from a generic failure.
class OnboardingException implements Exception {
  final String code;
  OnboardingException(this.code);
}

/// Result of creating an account: the new uid plus the throwaway password,
/// which the caller threads (in memory only) into createFirstCapacityPost if
/// the admin proceeds to add a first post. Never persist or display either.
typedef OnboardingAccount = ({String uid, String password});

/// Admin-only service for the optional phone-onboarding path. Deliberately
/// does NOT reuse CompanyService/CapacityService — those write through
/// FirebaseFirestore.instance (the admin's primary session), which would
/// defeat the whole point. Account creation and the first post go through a
/// throwaway [SecondaryFirebaseSession] so the new company's own auth context
/// satisfies the existing owner-uid Firestore rules with zero rule changes;
/// profile refinement and the invite flag go through the admin's own session
/// using the existing isAdmin()-gated company update branch.
class AdminOnboardingService {
  final FirebaseFirestore _adminFirestore = FirebaseFirestore.instance;

  /// Creates the Auth account + users/{uid} + companies/{uid}, all through one
  /// throwaway secondary session that is disposed before this returns. Returns
  /// the new uid and the throwaway password.
  Future<OnboardingAccount> createCompanyAccount({
    required String email,
    required CompanyModel companyDraft,
    required String adminUid,
  }) async {
    final session = SecondaryFirebaseSession();
    await session.start();
    try {
      final password = _generateThrowawayPassword();

      late final UserCredential cred;
      try {
        cred = await session.auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        throw OnboardingException(e.code);
      }
      final uid = cred.user!.uid;

      await session.firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'firstName': '',
        'lastName': '',
        'plan': 'free',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final company = companyDraft.copyWith(
        id: uid,
        ownerId: uid,
        onboardingSource: 'admin',
        onboardingAdminUid: adminUid,
      );
      // Public profile + gated contact sidecar, both through the secondary
      // session so the NEW company owns them (satisfies the owner branch of
      // the companyContacts write rule). Contact must never land on the
      // world-readable company doc — see CompanyModel's class doc.
      final companyBatch = session.firestore.batch();
      companyBatch.set(
        session.firestore.collection('companies').doc(uid),
        company.toFirestore(),
      );
      companyBatch.set(
        session.firestore.collection('companyContacts').doc(uid),
        company.toContactFirestore(),
      );
      await companyBatch.commit();

      return (uid: uid, password: password);
    } finally {
      await session.dispose();
    }
  }

  /// Optionally posts the company's first capacity. Needs its OWN fresh
  /// secondary session and re-auth (createCompanyAccount's session is already
  /// gone — each step is independent so an abandoned flow never leaks a
  /// long-lived throwaway session). Uses the same throwaway password from
  /// account creation, held only in memory by the caller.
  Future<void> createFirstCapacityPost({
    required String email,
    required String throwawayPassword,
    required CapacityModel capacityDraft,
    required CapacityOwnerModel ownerDraft,
  }) async {
    final session = SecondaryFirebaseSession();
    await session.start();
    try {
      await session.auth.signInWithEmailAndPassword(
        email: email,
        password: throwawayPassword,
      );
      // Both docs via the secondary session so the new company owns them
      // (satisfies the capacities / capacityOwners create rules).
      final ref = session.firestore.collection('capacities').doc();
      final batch = session.firestore.batch();
      batch.set(ref, capacityDraft.toFirestore());
      batch.set(
        session.firestore.collection('capacityOwners').doc(ref.id),
        ownerDraft.toFirestore(),
      );
      await batch.commit();
    } finally {
      await session.dispose();
    }
  }

  /// Refines the company profile after creation. Runs through the admin's own
  /// session — the companies update rule's `isAdmin()` branch permits this, no
  /// secondary session needed. toFirestoreForUpdate() deliberately omits the
  /// onboarding fields, so they're preserved untouched.
  Future<void> updateCompanyProfile(
    String companyId,
    CompanyModel company,
  ) async {
    // Mirrors CompanyService.updateCompany: the public doc plus the gated
    // contact sidecar, set(merge:true) since a company onboarded before the
    // contact split has no sidecar document yet. Runs as the admin, which the
    // companyContacts write rule permits alongside the owner.
    final batch = _adminFirestore.batch();
    batch.update(
      _adminFirestore.collection('companies').doc(companyId),
      company.toFirestoreForUpdate(),
    );
    batch.set(
      _adminFirestore.collection('companyContacts').doc(companyId),
      company.toContactFirestore(),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Stamps invitedAt the moment the admin sends the set-password invite.
  Future<void> markInvited(String companyId) async {
    await _adminFirestore
        .collection('companies')
        .doc(companyId)
        .update({'invitedAt': FieldValue.serverTimestamp()});
  }

  /// Cryptographically-secure throwaway password. 24 random bytes, base64url —
  /// comfortably exceeds Firebase's 6-char minimum. Never shown, logged, or
  /// persisted; the company overwrites it via the reset link before first use.
  String _generateThrowawayPassword() {
    final rng = Random.secure();
    final bytes = List<int>.generate(24, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
