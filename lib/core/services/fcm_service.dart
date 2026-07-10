import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../constants/app_constants.dart';

/// Web push (FCM) registration. Wrapped end-to-end in try/catch and never
/// awaited by its caller — a denied/unsupported browser permission must not
/// block sign-in or dashboard load, same fail-open posture as App Check
/// activation in main.dart. Requires kFcmVapidKey (Firebase Console → Cloud
/// Messaging) to actually receive a token; until that's set this silently
/// no-ops, so the rest of the app is unaffected.
class FcmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerForUser(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return;

      final token = await messaging.getToken(vapidKey: kFcmVapidKey);
      if (token != null) await _saveToken(uid, token);

      messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));
    } catch (_) {
      // Unsupported browser, permission dismissed, no VAPID key yet, etc.
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
