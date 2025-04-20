import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/item_providers.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inventoryStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.pushNamed(AppRoutes.managePickers),
            tooltip: 'Manage Pickers',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.pushNamed(AppRoutes.addItemName),
            tooltip: 'Add Item',
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No items in inventory'),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('SKU: ${item.sku}'),
                trailing: Text('Qty: ${item.quantity}'),
                onTap: () => context.pushNamed(
                  AppRoutes.editItemName,
                  pathParameters: {'id': item.id},
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
} 