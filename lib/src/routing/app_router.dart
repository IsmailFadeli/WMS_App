import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async'; // Import dart:async for StreamSubscription
import '../providers/auth_providers.dart'; // Import auth state provider
import '../screens/auth/login_screen.dart'; // Import login screen
import '../screens/home/home_screen.dart'; // Import home screen
import '../screens/items/add_item_screen.dart'; // Import AddItemScreen
import '../screens/items/edit_item_screen.dart'; // Import EditItemScreen
import '../screens/orders/orders_screen.dart'; // Import OrdersScreen
import '../screens/orders/add_order_screen.dart'; // Import AddOrderScreen
import '../screens/orders/order_details_screen.dart'; // Import OrderDetailsScreen
import '../screens/orders/picking_screen.dart';

// Define route paths AND names as constants
class AppRoutes {
  static const String login = '/login'; // Path for login
  static const String home = '/'; // Path for home
  static const String addItem = '/items/add'; // Path for add item
  static const String editItem = '/items/edit/:itemId'; // Path for edit item
  static const String orders = '/orders'; // Path for orders
  static const String addOrder = '/orders/add'; // Path for add order
  static const String orderDetails = '/orders/:orderId'; // Path for order details
  static const String picking = '/orders/picking/:orderId';

  // --- Nested Routes ---
  // Use simple names for constants used with pushNamed/GoRoute name property
  static const String addItemName = 'addItem'; // NAME for add item route
  static const String editItemName = 'editItem'; // NAME for edit item route
  static const String addOrderName = 'addOrder'; // NAME for add order route
  static const String orderDetailsName = 'orderDetails'; // NAME for order details route
  static const String pickingName = 'picking';

  // Define paths separately if needed, or combine if simple
  static const String addItemPath = 'add-item'; // PATH for add item route
  static const String editItemPath = 'edit-item/:itemId'; // PATH for edit item route

  // Helper method to generate the edit item path
  static String editItemById(String itemId) => '/items/edit/$itemId';
}

// Provider to expose the GoRouter instance
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true, // Enable extra logging for debugging navigation issues
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.addItem,
        name: AppRoutes.addItemName,
        builder: (context, state) => const AddItemScreen(),
      ),
      GoRoute(
        path: AppRoutes.editItem,
        name: AppRoutes.editItemName,
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return EditItemScreen(itemId: itemId);
        },
      ),
      GoRoute(
        path: AppRoutes.orders,
        name: 'orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.addOrder,
        name: AppRoutes.addOrderName,
        builder: (context, state) => const AddOrderScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderDetails,
        name: AppRoutes.orderDetailsName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return OrderDetailsScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.picking,
        name: AppRoutes.pickingName,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          return PickingScreen(orderId: orderId);
        },
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
