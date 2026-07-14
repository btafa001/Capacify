import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          'verificationStatus': vatNumber.isNotEmpty ? 'pending' : 'none',
          'ratingSum': 0,
          'ratingCount': 0,
          'contentFlagged': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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
  Future<void> sendPasswordResetEmail(
    String email, {
    String? languageCode,
    String? continueUrl,
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
        return 'Diese Anmeldeart ist nicht aktiviert. (Google in der Firebase-Konsole freischalten.)';
      case 'unauthorized-domain':
        return 'Diese Domain ist nicht für die Anmeldung freigegeben. (In Firebase Auth → Authorized domains hinzufügen.)';
      case 'popup-blocked':
        return 'Das Anmeldefenster wurde vom Browser blockiert. Bitte Popups für diese Seite erlauben.';
      case 'account-exists-with-different-credential':
        return 'Zu dieser E-Mail existiert bereits ein Konto mit einer anderen Anmeldeart.';
      case 'network-request-failed':
        return 'Netzwerkfehler. Bitte prüfen Sie Ihre Verbindung und versuchen Sie es erneut.';
      default:
        // App Check enforcement rejects Auth with a generic internal/unknown
        // code whose message mentions App Check or an HTTP 401 — call that out
        // distinctly so a config/enforcement outage (e.g. a broken reCAPTCHA
        // token exchange) doesn't masquerade as a random glitch or bad
        // password. Every other unknown failure carries its raw code so it's
        // diagnosable in support instead of a dead-end message.
        final detail = '${e.code} ${e.message ?? ''}'.toLowerCase();
        if (detail.contains('app check') ||
            detail.contains('app-check') ||
            detail.contains('appcheck')) {
          return 'Sicherheitsprüfung (App Check) fehlgeschlagen. Bitte laden Sie die Seite neu. Tritt das weiterhin auf, ist App Check vermutlich falsch konfiguriert.';
        }
        return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen. (Code: ${e.code})';
    }
  }
}