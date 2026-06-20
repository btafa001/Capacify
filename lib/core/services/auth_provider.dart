import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

// Provides the AuthService instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Watches the login state — rebuilds widgets when user logs in or out
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});