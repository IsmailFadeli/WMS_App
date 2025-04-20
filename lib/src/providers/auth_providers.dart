import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart'; // Import the AuthService

// Provider to expose an instance of AuthService
// Use Provider for services that don't change state themselves but provide methods
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// StreamProvider to expose the stream of authentication state changes
// This automatically handles listening to the stream and rebuilding widgets
// when the auth state changes (User logs in or out).
final authStateProvider = StreamProvider<User?>((ref) {
  // Watch the AuthService provider to get the instance
  final authService = ref.watch(authServiceProvider);
  // Return the stream from the AuthService
  return authService.authStateChanges();
});
