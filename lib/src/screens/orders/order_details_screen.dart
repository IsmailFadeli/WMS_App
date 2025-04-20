import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../providers/item_providers.dart';
import 'package:intl/intl.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderStream = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: orderStream.when(
        data: (order) {
          if (order == null) {
            return const Center(
              child: Text('Order not found'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${order.orderNumber}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            _buildStatusChip(order.status),
                          ],
                        ),
                        const Divider(),
                        _buildInfoRow('Created', DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt.toDate())),
                        if (order.updatedAt != null)
                          _buildInfoRow('Last Updated', DateFormat('MMM dd, yyyy HH:mm').format(order.updatedAt!.toDate())),
                        if (order.status == OrderStatus.completed && order.pickerFullName != null)
                          _buildInfoRow('Picked by', order.pickerFullName!),
                        if (order.notes != null && order.notes!.isNotEmpty)
                          _buildInfoRow('Notes', order.notes!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Store Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Information',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(),
                        if (order.storeName != null)
                          _buildInfoRow('Store Name', order.storeName!),
                        if (order.storeLocation != null)
                          _buildInfoRow('Store Location', order.storeLocation!),
                        if (order.storeReference != null)
                          _buildInfoRow('Reference', order.storeReference!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Order Items
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Items',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${order.items.length} items',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const Divider(),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: order.items.length,
                          itemBuilder: (context, index) {
                            final item = order.items[index];
                            return ListTile(
                              title: Text(item.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SKU: ${item.sku}'),
                                  Text('Location: ${item.location}'),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Qty: ${item.quantity}',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                if (order.notes != null && order.notes!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Divider(),
                          Text(order.notes!),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error loading order: $error'),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color backgroundColor;
    Color textColor = Colors.white;
    String text = status.toString().split('.').last;
    text = text[0].toUpperCase() + text.substring(1);

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange;
        break;
      case OrderStatus.processing:
      case OrderStatus.ready:
        backgroundColor = Colors.blue;
        break;
      case OrderStatus.completed:
        backgroundColor = Colors.green;
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 