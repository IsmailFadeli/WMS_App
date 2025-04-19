import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

/// A service class to interact with Firebase Authentication.
/// Provides methods for signing in, signing out, and listening to auth state changes.
class AuthService {
  // Get the FirebaseAuth instance
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Stream that emits the current user when the authentication state changes.
  /// Emits null if the user is signed out.
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  /// Gets the current logged-in user, if any.
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  /// Signs in a user with the given email and password.
  /// Returns the UserCredential on success.
  /// Throws a FirebaseAuthException on failure.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Attempt to sign in
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(), // Trim whitespace
        password: password.trim(),
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Optional: Log the specific error code for debugging
      if (kDebugMode) {
        print('FirebaseAuthException during sign in: ${e.code}');
      }
      // Re-throw the exception to be handled by the UI layer
      rethrow;
    } catch (e) {
      // Catch any other unexpected errors
       if (kDebugMode) {
        print('Unexpected error during sign in: $e');
      }
      // Rethrow as a generic exception or a specific custom exception
      throw Exception('An unexpected error occurred during sign in.');
    }
  }

  /// Signs out the current user.
  /// Handles potential errors during sign out.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
       if (kDebugMode) {
         print('FirebaseAuthException during sign out: ${e.code}');
       }
       // Depending on the app, you might want to inform the user
       // or just log the error. For simplicity, we just log here.
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error during sign out: $e');
      }
      // Rethrow or handle as needed
      throw Exception('An unexpected error occurred during sign out.');
    }
  }

  // Add other methods like signUp, resetPassword etc. as needed
  // Future<UserCredential> signUpWithEmailAndPassword(...) { ... }
  // Future<void> sendPasswordResetEmail(...) { ... }
}
