import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuthException
import '../../providers/auth_providers.dart'; // Import providers

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Controllers for the text fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // GlobalKey to manage the Form state and validation
  final _formKey = GlobalKey<FormState>();
  // Local state to track loading status
  bool _isLoading = false;
  // Local state to store potential error messages
  String? _errorMessage;

  @override
  void dispose() {
    // Dispose controllers when the widget is removed from the tree
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Function to handle the login process
  Future<void> _login() async {
    // Validate the form fields
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true; // Show loading indicator
        _errorMessage = null; // Clear previous errors
      });

      try {
        // Access the AuthService via the provider and attempt sign in
        await ref.read(authServiceProvider).signInWithEmailAndPassword(
              email: _emailController.text,
              password: _passwordController.text,
            );
        // Login successful - navigation will be handled by go_router redirect
        // No need to explicitly navigate here if router redirect is set up.

        // If successful, router redirect should handle navigation.
        // We might not even reach the line below if redirect happens immediately.
        if (mounted) { // Check if the widget is still in the tree
           setState(() { _isLoading = false; });
        }

      } on FirebaseAuthException catch (e) {
        // Handle specific Firebase Auth errors
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Provide user-friendly error messages
            _errorMessage = switch (e.code) {
              'user-not-found' => 'No user found for that email.',
              'wrong-password' => 'Wrong password provided.',
              'invalid-email' => 'The email address is not valid.',
              'user-disabled' => 'This user account has been disabled.',
              'too-many-requests' => 'Too many login attempts. Please try again later.',
              'network-request-failed' => 'Network error. Please check your connection.',
              _ => 'An unknown error occurred. (${e.code})', // Default message
            };
          });
        }
      } catch (e) {
        // Handle other potential errors
         if (mounted) {
           setState(() {
            _isLoading = false;
            _errorMessage = 'An unexpected error occurred. Please try again.';
          });
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login - WMS'),
      ),
      body: Center(
        child: SingleChildScrollView( // Allows scrolling on smaller screens
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox( // Limit the width on larger screens
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Warehouse Login',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32.0),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true, // Hide password characters
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      // Add more complex password rules if needed
                      return null;
                    },
                  ),
                  const SizedBox(height: 24.0),

                  // Error Message Display
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Login Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _login, // Call the login function
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            textStyle: const TextStyle(fontSize: 16.0),
                          ),
                          child: const Text('Login'),
                        ),

                  // Optional: Add links for Sign Up or Forgot Password
                  // TextButton(
                  //   onPressed: () { /* Navigate to Sign Up */ },
                  //   child: const Text('Don\'t have an account? Sign Up'),
                  // ),
                  // TextButton(
                  //   onPressed: () { /* Navigate to Forgot Password */ },
                  //   child: const Text('Forgot Password?'),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
