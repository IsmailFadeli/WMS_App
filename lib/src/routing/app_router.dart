import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async'; // Import dart:async for StreamSubscription
import '../providers/auth_providers.dart'; // Import auth state provider
import '../screens/auth/login_screen.dart'; // Import login screen
import '../screens/home/home_screen.dart'; // Import home screen
import '../screens/items/add_item_screen.dart'; // Import AddItemScreen
import '../screens/items/edit_item_screen.dart'; // Import EditItemScreen

// Define route paths AND names as constants
class AppRoutes {
  static const String login = '/login'; // Path for login
  static const String home = '/'; // Path for home

  // --- Nested Routes ---
  // Use simple names for constants used with pushNamed/GoRoute name property
  static const String addItem = 'addItem'; // NAME for add item route
  static const String editItem = 'editItem'; // NAME for edit item route

  // Define paths separately if needed, or combine if simple
  static const String addItemPath = 'add-item'; // PATH for add item route
  static const String editItemPath = 'edit-item/:itemId'; // PATH for edit item route
}

// Provider to expose the GoRouter instance
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true, // Enable extra logging for debugging navigation issues
    routes: [
      GoRoute(
        path: AppRoutes.login,
        // No name needed for login if not navigating to it by name
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.home, // Optional: Name home if needed
        builder: (context, state) => const HomeScreen(),
        // Nested routes accessible from home
        routes: [
          GoRoute(
            name: AppRoutes.addItem, // Use the simple NAME constant
            path: AppRoutes.addItemPath, // Use the PATH constant
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: const AddItemScreen(),
            ),
          ),
          GoRoute(
            name: AppRoutes.editItem, // Use the simple NAME constant
            path: AppRoutes.editItemPath, // Use the PATH constant (contains :itemId)
            pageBuilder: (context, state) {
              // Extract item ID, handle potential null
              final itemId = state.pathParameters['itemId'];
              if (itemId == null) {
                // Handle error: Navigate back or show error page
                return MaterialPage(
                  key: state.pageKey,
                  child: Scaffold(
                      appBar: AppBar(title: const Text("Error")),
                      body: const Center(child: Text("Item ID missing"))),
                );
              }
              return MaterialPage(
                key: state.pageKey,
                fullscreenDialog: true,
                child: EditItemScreen(itemId: itemId), // Pass ID to screen
              );
            },
          ),
        ],
      ),
    ],

    // Redirect logic
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggingIn = state.matchedLocation == AppRoutes.login;
      final bool loggedIn = authState.maybeWhen(
          data: (user) => user != null,
          orElse: () => false
          );

      if (authState.isLoading) return null; // Don't redirect until auth state is known

      // Check if accessing a route that requires authentication
      // Need to check the resolved full path for nested routes
      final String currentRouteFullPath = state.fullPath ?? state.uri.toString();
      final bool accessingProtectedArea = !loggingIn; // Any route other than login requires auth

      // If not logged in and trying to access a protected area
      if (!loggedIn && accessingProtectedArea) {
        return AppRoutes.login;
      }

      // If logged in and trying to access login
      if (loggedIn && loggingIn) {
        return AppRoutes.home;
      }

      return null; // No redirect needed
    },

    refreshListenable: GoRouterRefreshStream(ref.watch(authStateProvider.stream)),

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text('Error: ${state.error?.message ?? 'Page not found'}'),
      ),
    ),
  );
});

// Helper class GoRouterRefreshStream (keep as is)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
