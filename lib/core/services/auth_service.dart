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
    String trade = '',
    String city = '',
    String phone = '',
    String website = '',
    String companyEmail = '',
    String vatNumber = '',
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
          'trade': trade,
          'city': city,
          'phone': phone,
          'website': website,
          'email': companyEmail.isNotEmpty
              ? companyEmail
              : email,
          'description': '',
          'address': '',
          'postalCode': '',
          'country': 'Deutschland',
          'employees': '1-5',
          'services': [],
          'logoUrl': '',
          'vatNumber': vatNumber,
          'verificationStatus': vatNumber.isNotEmpty ? 'pending' : 'none',
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
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
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
      default:
        return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';
    }
  }
}