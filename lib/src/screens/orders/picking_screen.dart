import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../providers/firestore_providers.dart' as firestore_providers;
import '../../providers/order_providers.dart' as order_providers;
import '../scanner/barcode_scanner_screen.dart';
import '../../models/item.dart';
import '../../providers/item_providers.dart';
import '../../models/picker.dart';
import '../../providers/picker_providers.dart';

class PickingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PickingScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<PickingScreen> createState() => _PickingScreenState();
}

class _PickingScreenState extends ConsumerState<PickingScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  Map<String, int> _scannedItems = {};
  bool _isLoading = false;

  // Predefined store list
  static const List<String> storeList = [
    'E-COM',
    'BEZ',
    'CHE',
    'CC',
    'AD',
    'ORN',
    'AZ',
    'ARD',
    'STF',
  ];

  @override
  void initState() {
    super.initState();
    _loadScannedItems();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadScannedItems() async {
    setState(() => _isLoading = true);
    try {
      final scannedItems = await ref.read(firestore_providers.firestoreServiceProvider).getScannedItems(widget.orderId);
      setState(() => _scannedItems = scannedItems);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading scanned items: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(order_providers.orderProvider(widget.orderId));
    final pickersAsync = ref.watch(pickersProvider);
    final selectedPicker = ref.watch(selectedPickerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Picking Order'),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          return Column(
            children: [
              // Picker selection at the top
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: pickersAsync.when(
                  data: (pickers) {
                    if (pickers.isEmpty) {
                      return const Text('No pickers available');
                    }
                    return DropdownButtonFormField<Picker>(
                      decoration: const InputDecoration(
                        labelText: 'Select Picker',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedPicker,
                      items: pickers.map((picker) {
                        return DropdownMenuItem(
                          value: picker,
                          child: Text(picker.fullName),
                        );
                      }).toList(),
                      onChanged: (picker) {
                        ref.read(selectedPickerProvider.notifier).state = picker;
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, stack) => Text('Error: $error'),
                ),
              ),
              // Store Name
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.store,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        order.storeName ?? 'No store name',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Order Notes
              if (order.notes != null && order.notes!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.notes!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: order.items.length,
                        itemBuilder: (context, index) {
                          final item = order.items[index];
                          final scannedQuantity = _scannedItems[item.id] ?? 0;
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SKU: ${item.sku}'),
                                Text('Location: ${item.location}'),
                                Text('Scanned: $scannedQuantity / ${item.quantity}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () => _showItemDetails(item),
                                  tooltip: 'View Item Details',
                                ),
                                if (scannedQuantity >= item.quantity)
                                  const Icon(Icons.check_circle, color: Colors.green)
                                else
                                  const Icon(Icons.pending, color: Colors.orange),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _barcodeController,
                            focusNode: _barcodeFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'Scan Barcode',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (value) async {
                              if (value.isEmpty) return;
                              await _handleBarcodeScan(value, order);
                              _barcodeController.clear();
                              _barcodeFocusNode.requestFocus();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (order.items.every((item) => 
                      (_scannedItems[item.id] ?? 0) >= item.quantity
                    ))
                      ElevatedButton.icon(
                        onPressed: () => _completeOrder(order),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Progress'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (barcode != null && mounted) {
      final orderAsyncValue = ref.read(order_providers.orderProvider(widget.orderId));
      if (orderAsyncValue.hasValue && orderAsyncValue.value != null) {
        await _handleBarcodeScan(barcode, orderAsyncValue.value!);
      }
    }
  }

  Future<void> _handleBarcodeScan(String barcode, Order order) async {
    try {
      // Try to find the item in the order by either ID or barcode
      final item = order.items.firstWhere(
        (item) => item.id == barcode || item.barcode == barcode,
        orElse: () => throw Exception('Barcode $barcode not found in this order'),
      );

      final currentQuantity = _scannedItems[item.id] ?? 0;
      if (currentQuantity >= item.quantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} has already been fully scanned'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() => _scannedItems[item.id] = currentQuantity + 1);
      await ref.read(firestore_providers.firestoreServiceProvider).updateScannedItems(
            widget.orderId,
            _scannedItems,
          );

      if (_scannedItems[item.id] == item.quantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} fully scanned'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name}: ${_scannedItems[item.id]} of ${item.quantity} scanned'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeOrder(Order order) async {
    final picker = ref.read(selectedPickerProvider);
    if (picker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a picker')),
      );
      return;
    }

    try {
      // First update the order with picker information
      await ref.read(firestore_providers.firestoreServiceProvider).updateOrderWithPicker(
        order.id,
        picker,
      );

      // Then complete the order
      await ref.read(firestore_providers.firestoreServiceProvider).completeOrder(order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order completed successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing order: $e')),
        );
      }
    }
  }

  Future<void> _showItemDetails(OrderItem orderItem) async {
    try {
      // Get the full item details from inventory
      final items = await ref.read(inventoryStreamProvider.future);
      final item = items.firstWhere(
        (item) => item.id == orderItem.id,
        orElse: () => throw Exception('Item not found in inventory'),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (item.imageUrl != null)
                  Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 80,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('SKU', item.sku),
                      const SizedBox(height: 8),
                      _buildDetailRow('Quantity', '${orderItem.quantity}'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Location', item.location),
                      if (item.barcode != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow('Barcode', item.barcode!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading item details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
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
} 