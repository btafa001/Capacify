import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // Updated register — also creates company
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    // Company fields
    String companyName = '',
    List<String> trades = const [],
    String address = '',
    String city = 'Hamburg',
    String postalCode = '',
    String phone = '',
    String website = '',
    String companyEmail = '',
    String vatNumber = '',
    String employees = '1-5',
  }) async {
    try {
      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Best-effort — a verification-email hiccup shouldn't block the account
      // being created. Posting/contacting stay gated on emailVerified either
      // way (firestore.rules), so there's always a way to retry via the
      // banner's resend button.
      try {
        await _sendVerificationEmail();
      } catch (_) {}

      // Create user document
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        // Tier flag for the gated-contact model — dormant; default free.
        'plan': 'free',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Auto-create company if name provided
      if (companyName.isNotEmpty) {
        await _firestore
            .collection('companies')
            .doc(credential.user!.uid)
            .set({
          'ownerId': credential.user!.uid,
          'administrators': [credential.user!.uid],
          'name': companyName,
          'trades': trades,
          'city': city,
          'phone': phone,
          'website': website,
          'email': companyEmail.isNotEmpty
              ? companyEmail
              : email,
          'description': '',
          'address': address,
          'postalCode': postalCode,
          'country': 'Deutschland',
          'employees': employees,
          'services': [],
          'logoUrl': '',
          'vatNumber': vatNumber,
          // Always 'none' at creation — 'pending' is reachable only via the
          // verifyMyCompany Cloud Function after a real VIES check (see
          // firestore.rules, which now rejects any other value here). This
          // param isn't wired into the registration UI today (vatNumber is
          // always '' from that call site), but the create rule would reject
          // the whole signup if a future UI change ever passed one through
          // with the old vatNumber.isNotEmpty-derived value.
          'verificationStatus': 'none',
          // Must match request.auth.token.email_verified (firestore.rules) —
          // true immediately for a provider that pre-verifies (not reachable
          // via this email/password path, but mirrors the OAuth create path
          // in company_profile_screen.dart), false for every fresh
          // email/password signup until the owner clicks the verification
          // link (see markEmailVerified / email_verification_banner.dart).
          // Directory listing is gated on this — see H3 fix notes on
          // CompanyModel.isDirectoryEligible.
          'emailVerified': credential.user!.emailVerified,
          'ratingSum': 0,
          'ratingCount': 0,
          'contentFlagged': false,
          'referredBy': _referrerFromUrl(excludeUid: credential.user!.uid),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Reads ?ref={companyId} off the current page URL — the invite link's
  /// referral attribution (see invite_dialog.dart, which builds that link).
  /// Excludes self-referral (shouldn't be reachable normally, since the
  /// referrer's id was minted before this new account existed, but cheap to
  /// guard directly). Best-effort: any malformed/missing param → ''.
  String _referrerFromUrl({required String excludeUid}) {
    try {
      final ref = Uri.base.queryParameters['ref'];
      if (ref == null || ref.isEmpty || ref == excludeUid) return '';
      return ref;
    } catch (_) {
      return '';
    }
  }

  // ── Social sign-in (web: signInWithPopup) ──────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final credential = await _auth.signInWithPopup(provider);
      await _ensureUserDoc(credential.user!);
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') return null;
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      final credential = await _auth.signInWithPopup(provider);
      await _ensureUserDoc(credential.user!);
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') return null;
      throw _handleAuthException(e);
    }
  }

  Future<void> _ensureUserDoc(User user) async {
    final doc =
        await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      final parts = (user.displayName ?? '').trim().split(' ');
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'firstName': parts.isNotEmpty ? parts.first : '',
        'lastName': parts.length > 1 ? parts.sublist(1).join(' ') : '',
        'plan': 'free',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    touchLastActive(user.uid);
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String phone,
    required String jobTitle,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'jobTitle': jobTitle,
    }, SetOptions(merge: true));
  }

  /// Whether the user wants an email when they receive a new contact request
  /// (poster inbox). Defaults ON when unset. The preference is stored here; the
  /// actual send is done by the mail backend (see docs/notifications) which
  /// reads this flag before emailing — the client can't email the poster
  /// directly (poster identity is server-hidden by design).
  Future<bool> getEmailNotifications(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['notifyByEmail'] as bool?) ?? true;
  }

  Future<void> setEmailNotifications({
    required String uid,
    required bool enabled,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'notifyByEmail': enabled}, SetOptions(merge: true));
  }

  /// Gates the onNewMessage Cloud Function's push + email for this user
  /// (defaults to true — opt-out, matching notifyByEmail above).
  Future<bool> getNotifyOnNewMessage(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['notifyOnNewMessage'] as bool?) ?? true;
  }

  Future<void> setNotifyOnNewMessage({
    required String uid,
    required bool enabled,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'notifyOnNewMessage': enabled}, SetOptions(merge: true));
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      touchLastActive(cred.user!.uid);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Stamps the company's `lastActiveAt` on login — a liveness/trust signal
  /// ("Zuletzt aktiv heute") shown on company profiles. Best-effort: a user
  /// without a company doc (or an offline blip) is silently ignored.
  void touchLastActive(String uid) {
    _firestore
        .collection('companies')
        .doc(uid)
        .update({'lastActiveAt': FieldValue.serverTimestamp()})
        .catchError((_) {});
  }

  /// Sends Firebase's password-reset email. This doubles as the admin-assisted
  /// onboarding "set your password" invite (see AdminOnboardingService).
  ///
  /// [languageCode] localizes the email Firebase sends (the built-in template
  /// respects the account language) — pass 'de' for German firms so the invite
  /// doesn't arrive in English. [continueUrl], when given, adds a "Continue"
  /// button that returns the user to the app after they set their password
  /// instead of leaving them on Firebase's bare confirmation page. The email's
  /// subject/body/sender and its deliverability (spam) are configured in the
  /// Firebase Console (Auth → Templates), NOT here.
  ///
  /// [suppressUserNotFound]: when true, a 'user-not-found' failure resolves
  /// silently instead of throwing — for the PUBLIC "forgot password" screen
  /// only. Showing a different outcome for "no account" vs. "email sent" is
  /// exactly what lets that screen be used to enumerate registered addresses
  /// (see the pre-launch audit's black-hat pass); no email goes out to a
  /// nonexistent address either way, so the UI should look identical too.
  /// Left false (the default) for the admin-invite call sites, where
  /// 'user-not-found' actually means something went wrong worth surfacing —
  /// those accounts should already exist by the time this is called.
  Future<void> sendPasswordResetEmail(
    String email, {
    String? languageCode,
    String? continueUrl,
    bool suppressUserNotFound = false,
  }) async {
    try {
      if (languageCode != null) {
        await _auth.setLanguageCode(languageCode);
      }
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: continueUrl == null
            ? null
            : ActionCodeSettings(url: continueUrl, handleCodeInApp: false),
      );
    } on FirebaseAuthException catch (e) {
      if (suppressUserNotFound && e.code == 'user-not-found') return;
      throw _handleAuthException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw 'Nicht angemeldet.';
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sends the "verify your email" message via our own branded Cloud Function
  /// (sendVerificationEmail in functions/index.js) — same real Firebase Auth
  /// verification link, but our own template/sender instead of the default
  /// Console-templated email, for both appearance and deliverability. Falls
  /// back to Firebase's own sendEmailVerification() if the function call
  /// fails for any reason (SMTP not configured, function unreachable, a
  /// stale deploy) so a user is never left without any verification email at
  /// all. The fallback's own errors still propagate normally.
  Future<void> _sendVerificationEmail() async {
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('sendVerificationEmail')
          .call();
    } catch (_) {
      final user = _auth.currentUser;
      if (user == null) return;
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        throw _handleAuthException(e);
      }
    }
  }

  /// Re-sends the verification email to the signed-in user — the resend
  /// button on the email-verification banner (see dashboard_screen.dart).
  Future<void> resendVerificationEmail() async {
    if (_auth.currentUser == null) return;
    await _sendVerificationEmail();
  }

  /// Refreshes the cached Auth user (and its ID token) from the server —
  /// needed because `currentUser.emailVerified` reflects whatever was true
  /// when the token was last issued, not the live state. Called by the
  /// verification banner's "I've verified" button after the user clicks the
  /// link in another tab and comes back.
  ///
  /// Also persists the flip onto companies/{uid}.emailVerified — the gate the
  /// public directory listing checks (see CompanyModel.isDirectoryEligible) —
  /// the moment it's actually true. getIdToken(true) above runs first so the
  /// fresh 'verified' claim is already on the token this write carries;
  /// firestore.rules independently re-checks that claim before accepting it,
  /// so this can't be forged by calling it early. Best-effort/silently
  /// ignored, same as touchLastActive: a user without a company doc yet (or
  /// an offline blip) shouldn't fail the refresh the banner is showing.
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) {
      _firestore
          .collection('companies')
          .doc(user.uid)
          .update({'emailVerified': true}).catchError((_) {});
    }
    return verified;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Kein Konto mit dieser E-Mail gefunden.';
      case 'wrong-password':
        return 'Falsches Passwort. Bitte erneut versuchen.';
      case 'email-already-in-use':
        return 'Diese E-Mail-Adresse wird bereits verwendet.';
      case 'weak-password':
        return 'Passwort muss mindestens 6 Zeichen haben.';
      case 'invalid-email':
        return 'Bitte geben Sie eine gültige E-Mail-Adresse ein.';
      case 'user-disabled':
        return 'Dieses Konto wurde deaktiviert.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte später erneut versuchen.';
      case 'invalid-credential':
        return 'E-Mail oder Passwort ist falsch.';
      // Social sign-in (Google/Apple) — surface the real cause so config issues
      // are diagnosable instead of a generic error.
      case 'operation-not-allowed':
        return 'Diese Anmeldeart ist nicht aktiviert. (Den Anbieter in der Firebase-Konsole unter Authentication → Sign-in method freischalten.)';
      case 'unauthorized-domain':
        return 'Diese Domain ist nicht für die Anmeldung freigegeben. (In Firebase Auth → Authorized domains hinzufügen.)';
      case 'popup-blocked':
        return 'Das Anmeldefenster wurde vom Browser blockiert. Bitte Popups für diese Seite erlauben.';
      case 'account-exists-with-different-credential':
        return 'Zu dieser E-Mail existiert bereits ein Konto mit einer anderen Anmeldeart.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';
      default:
        return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';
    }
  }
}