import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart';
import '../../providers/item_providers.dart';
import '../../routing/app_routes.dart';
import 'package:intl/intl.dart';

// Provider for selected store filter
final selectedStoreProvider = StateProvider<String?>((ref) => null);

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStore = ref.watch(selectedStoreProvider);
    final ordersAsyncValue = ref.watch(storeOrdersProvider);

    // Get unique store names from orders
    final storeNames = ordersAsyncValue.when(
      data: (orders) {
        final stores = orders
            .map((order) => order.storeName)
            .where((name) => name != null)
            .toSet()
            .toList();
        stores.sort();
        return stores;
      },
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Picking Orders'),
        actions: [
          // Store filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<String?>(
              value: selectedStore,
              hint: const Text('Filter by Store'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Stores'),
                ),
                ...storeNames.map((store) => DropdownMenuItem<String?>(
                      value: store,
                      child: Text(store!),
                    )),
              ],
              onChanged: (value) {
                ref.read(selectedStoreProvider.notifier).state = value;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.pushNamed(AppRoutes.managePickers),
            tooltip: 'Manage Pickers',
          ),
        ],
      ),
      body: const StoreOrdersList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.addOrderName),
        label: const Text('New Picking Order'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class StoreOrdersList extends ConsumerWidget {
  const StoreOrdersList({super.key});

  /// Cancel an order
  Future<void> _handleCancelOrder(BuildContext context, WidgetRef ref, Order order) async {
    try {
      await ref.read(firestoreServiceProvider).cancelStoreOrder(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel order: $e')),
        );
      }
    }
  }

  /// Delete a cancelled order
  Future<void> _handleDeleteOrder(BuildContext context, WidgetRef ref, Order order) async {
    try {
      await ref.read(firestoreServiceProvider).deleteStoreOrder(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete order: $e')),
        );
      }
    }
  }

  /// Show confirmation dialog before cancelling an order
  Future<void> _showCancelConfirmation(BuildContext context, WidgetRef ref, Order order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel order ${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _handleCancelOrder(context, ref, order);
    }
  }

  /// Show confirmation dialog before deleting an order
  Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref, Order order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Are you sure you want to delete order ${order.orderNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _handleDeleteOrder(context, ref, order);
    }
  }

  /// Handle starting the picking process for an order
  void _handleStartPicking(BuildContext context, Order order) {
    context.pushNamed(
      AppRoutes.pickingName,
      pathParameters: {'orderId': order.id},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsyncValue = ref.watch(storeOrdersProvider);
    final selectedStore = ref.watch(selectedStoreProvider);

    return ordersAsyncValue.when(
      data: (orders) {
        // Filter orders by selected store
        final filteredOrders = selectedStore == null
            ? orders
            : orders.where((order) => order.storeName == selectedStore).toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Text(
              selectedStore == null
                  ? 'No picking orders available'
                  : 'No orders found for $selectedStore',
            ),
          );
        }

        // Sort orders by status: pending first, then completed, then cancelled
        final sortedOrders = List<Order>.from(filteredOrders);
        sortedOrders.sort((a, b) {
          // Define priority for each status
          final statusPriority = {
            OrderStatus.pending: 0,
            OrderStatus.completed: 1,
            OrderStatus.cancelled: 2,
          };
          
          // Get priority for each order's status
          final priorityA = statusPriority[a.status] ?? 3;
          final priorityB = statusPriority[b.status] ?? 3;
          
          // Sort by priority
          if (priorityA != priorityB) {
            return priorityA.compareTo(priorityB);
          }
          
          // If same status, sort by creation date (newest first)
          return b.createdAt.compareTo(a.createdAt);
        });

        return ListView.builder(
          itemCount: sortedOrders.length,
          itemBuilder: (context, index) {
            final order = sortedOrders[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text('Order #${order.orderNumber}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${order.status.name}'),
                    Text('Total Quantity: ${order.items.fold(0, (sum, item) => sum + item.quantity)}'),
                    if (order.storeName != null) Text('Store: ${order.storeName}'),
                    Text('Created: ${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt.toDate())}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order.status == OrderStatus.pending)
                      ElevatedButton.icon(
                        onPressed: () => _handleStartPicking(context, order),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Picking'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (order.status == OrderStatus.completed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          label: const Text('Completed'),
                          backgroundColor: Colors.green.withOpacity(0.2),
                          labelStyle: const TextStyle(color: Colors.green),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () {
                        context.pushNamed(
                          AppRoutes.orderDetailsName,
                          pathParameters: {'orderId': order.id},
                        );
                      },
                    ),
                    if (order.status == OrderStatus.pending)
                      IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: () => _showCancelConfirmation(context, ref, order),
                      ),
                    if (order.status == OrderStatus.cancelled)
                      IconButton(
                        icon: const Icon(Icons.delete_forever),
                        onPressed: () => _showDeleteConfirmation(context, ref, order),
                      ),
                  ],
                ),
                onTap: () {
                  context.pushNamed(
                    AppRoutes.orderDetailsName,
                    pathParameters: {'orderId': order.id},
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading orders: $error'),
      ),
    );
  }
} 