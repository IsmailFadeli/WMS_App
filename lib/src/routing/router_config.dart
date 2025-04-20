import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/pickers/manage_pickers_screen.dart';
import '../screens/items/add_item_screen.dart';
import '../screens/items/edit_item_screen.dart';
import '../screens/orders/add_order_screen.dart';
import '../screens/orders/order_details_screen.dart';
import '../screens/orders/picking_screen.dart';
import '../screens/main_screen.dart';
import 'app_routes.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: AppRoutes.homeName,
      builder: (context, state) => const MainScreen(),
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
        final itemId = state.pathParameters['id']!;
        return EditItemScreen(itemId: itemId);
      },
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
    GoRoute(
      path: AppRoutes.pickers,
      name: AppRoutes.managePickers,
      builder: (context, state) => const ManagePickersScreen(),
    ),
  ],
); 