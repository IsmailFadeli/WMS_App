import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart' as order_model;
import '../../models/item.dart';
import '../../providers/item_providers.dart';
import '../../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routing/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:html' if (dart.library.html) 'dart:html' as html;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AddOrderScreen extends ConsumerStatefulWidget {
  const AddOrderScreen({super.key});

  @override
  ConsumerState<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends ConsumerState<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStore;
  final _storeReferenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesItemController = TextEditingController();

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

  List<order_model.OrderItem> _orderItems = [];
  order_model.OrderType _orderType = order_model.OrderType.store;
  bool _isLoading = false;
  Item? _selectedItem;

  @override
  void dispose() {
    _storeReferenceController.dispose();
    _notesController.dispose();
    _skuController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    _notesItemController.dispose();
    super.dispose();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => AddOrderItemDialog(
        onItemAdded: (item) {
          setState(() {
            _orderItems.add(item);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AddOrderItemDialog(
        initialItem: _orderItems[index],
        onItemAdded: (updatedItem) {
          setState(() {
            _orderItems[index] = updatedItem;
          });
        },
      ),
    );
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate() || _orderItems.isEmpty || _selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields and add at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final order = order_model.Order(
        id: '', // Will be set by Firestore
        orderNumber: '', // Will be generated
        type: _orderType,
        status: order_model.OrderStatus.pending,
        storeName: _selectedStore!,
        storeReference: _storeReferenceController.text.trim(),
        items: _orderItems,
        notes: _notesController.text.trim(),
        totalAmount: _orderItems.fold(0.0, (sum, item) => sum + item.quantity),
        createdAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
      );

      final firestoreService = ref.read(firestoreServiceProvider);
      final orderId = await firestoreService.createStoreOrder(order);

      if (!mounted) return;

      // Show success message with View Order button
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Order created successfully'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View Order',
            textColor: Colors.white,
            onPressed: () {
              context.pushNamed(
                AppRoutes.orderDetails,
                pathParameters: {'orderId': orderId},
              );
            },
          ),
        ),
      );
      context.pop(); // Go back to orders screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addOrderItem() {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select an item first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final orderItem = order_model.OrderItem(
      id: _selectedItem!.id,
      sku: _selectedItem!.sku,
      name: _selectedItem!.name,
      quantity: quantity,
      location: _selectedItem!.location,
    );

    setState(() {
      _orderItems.add(orderItem);
      _clearItemFields();
    });
  }

  void _clearItemFields() {
    _selectedItem = null;
    _skuController.clear();
    _nameController.clear();
    _locationController.clear();
    _quantityController.clear();
    _notesItemController.clear();
  }

  Future<void> _importItemsFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw Exception('No file data found');
      }

      // Create a new Excel document from bytes
      final excel = Excel.decodeBytes(bytes);
      
      // Get the first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;
      
      // Skip header row and process data rows
      final newItems = <order_model.OrderItem>[];
      
      // Get all items from inventory for barcode lookup
      final items = await ref.read(inventoryStreamProvider.future);
      
      // Process each row
      for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        try {
          // Get cell values as strings
          String getCellValue(int col) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
            if (cell.value == null) return '';
            return cell.value.toString();
          }
          
          final barcode = getCellValue(0);
          final quantityStr = getCellValue(1);
          
          // Skip empty rows
          if (barcode.isEmpty) continue;
          
          // Parse quantity
          final quantity = int.tryParse(quantityStr) ?? 0;
          if (quantity <= 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invalid quantity in row ${rowIndex + 1}: $quantityStr'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            continue;
          }

          // Find item by barcode
          final item = items.firstWhere(
            (item) => item.barcode?.toLowerCase() == barcode.toLowerCase(),
            orElse: () => throw Exception('No item found with barcode: $barcode'),
          );
          
          final orderItem = order_model.OrderItem(
            id: item.id,
            sku: item.sku,
            name: item.name,
            quantity: quantity,
            location: item.location,
            barcode: item.barcode,
          );
          newItems.add(orderItem);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error processing row ${rowIndex + 1}: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (newItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid items found in the Excel file'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _orderItems.addAll(newItems);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${newItems.length} items'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing Excel file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      // Create a new Excel document
      final excel = Excel.createExcel();
      final sheet = excel['Order Items'];

      // Add headers with styling
      final headers = ['Barcode', 'Quantity'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        // Add header styling
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Add sample data with more realistic examples
      final sampleData = [
        ['123456789', '5'],
        ['987654321', '3'],
        ['456789123', '2'],
        ['789123456', '10'],
        ['321654987', '4'],
      ];

      for (var row = 0; row < sampleData.length; row++) {
        for (var col = 0; col < sampleData[row].length; col++) {
          final value = sampleData[row][col];
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
          
          if (col == 1) { // Quantity column
            cell.value = IntCellValue(int.parse(value));
          } else {
            cell.value = TextCellValue(value);
          }
        }
      }

      // Add instructions sheet
      final instructionsSheet = excel['Instructions'];
      final instructions = [
        'Instructions for Order Items Import',
        '',
        '1. File Format:',
        '   - Use .xlsx or .xls format',
        '   - Keep the header row as is',
        '   - Fill in your data starting from row 2',
        '',
        '2. Required Fields:',
        '   - Barcode: The item barcode (required)',
        '   - Quantity: Must be a positive number (required)',
        '',
        '3. Notes:',
        '   - Do not modify the header row',
        '   - Both fields are required',
        '   - Quantity must be a positive number',
        '   - Remove example rows before importing',
        '   - Item details will be automatically filled based on barcode',
      ];

      for (var i = 0; i < instructions.length; i++) {
        final cell = instructionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i));
        cell.value = TextCellValue(instructions[i]);
        if (i == 0) {
          cell.cellStyle = CellStyle(
            bold: true,
            fontSize: 14,
          );
        }
      }

      // Encode the Excel file
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      if (kIsWeb) {
        // For web platform
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'order_items_template.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // For desktop platforms
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Order Items Template',
          fileName: 'order_items_template.xlsx',
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsBytes(bytes);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Order'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveOrder,
              tooltip: 'Save Order',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Order Type Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<order_model.OrderType>(
                      segments: const [
                        ButtonSegment<order_model.OrderType>(
                          value: order_model.OrderType.store,
                          label: Text('Store Order'),
                          icon: Icon(Icons.store),
                        ),
                        ButtonSegment<order_model.OrderType>(
                          value: order_model.OrderType.ecommerce,
                          label: Text('E-commerce'),
                          icon: Icon(Icons.shopping_cart),
                        ),
                      ],
                      selected: {_orderType},
                      onSelectionChanged: (Set<order_model.OrderType> selected) {
                        setState(() {
                          _orderType = selected.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Store Information
            if (_orderType == order_model.OrderType.store)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Store Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedStore,
                        decoration: const InputDecoration(
                          labelText: 'Store Name *',
                          border: OutlineInputBorder(),
                        ),
                        items: storeList.map((String store) {
                          return DropdownMenuItem<String>(
                            value: store,
                            child: Text(store),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStore = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a store';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _storeReferenceController,
                        decoration: const InputDecoration(
                          labelText: 'Store Reference',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Order Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
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
                        const Text(
                          'Order Items',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: _downloadTemplate,
                              tooltip: 'Download Template',
                            ),
                            IconButton(
                              icon: const Icon(Icons.file_upload),
                              onPressed: _importItemsFromExcel,
                              tooltip: 'Import from Excel',
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addItem,
                              tooltip: 'Add Item',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_orderItems.isEmpty)
                      const Center(
                        child: Text('No items added yet'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _orderItems.length,
                        itemBuilder: (context, index) {
                          final item = _orderItems[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text('Quantity: ${item.quantity}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editItem(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddOrderItemDialog extends ConsumerStatefulWidget {
  final order_model.OrderItem? initialItem;
  final Function(order_model.OrderItem) onItemAdded;

  const AddOrderItemDialog({
    super.key,
    this.initialItem,
    required this.onItemAdded,
  });

  @override
  ConsumerState<AddOrderItemDialog> createState() => _AddOrderItemDialogState();
}

class _AddOrderItemDialogState extends ConsumerState<AddOrderItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _locationController;
  late final TextEditingController _barcodeController;
  bool _isLoading = false;
  Item? _selectedItem;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.initialItem?.sku ?? '');
    _nameController = TextEditingController(text: widget.initialItem?.name ?? '');
    _quantityController = TextEditingController(
      text: widget.initialItem?.quantity.toString() ?? '1',
    );
    _locationController = TextEditingController(text: widget.initialItem?.location ?? '');
    _barcodeController = TextEditingController(text: widget.initialItem?.barcode ?? '');
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _searchItemByBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final items = await ref.read(inventoryStreamProvider.future);
      final item = items.firstWhere(
        (item) => item.barcode?.toLowerCase() == barcode.toLowerCase(),
        orElse: () => throw Exception('No item found with barcode: $barcode'),
      );

      setState(() {
        _selectedItem = item;
        _skuController.text = item.sku;
        _nameController.text = item.name;
        _locationController.text = item.location;
        _barcodeController.text = item.barcode ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveItem() {
    if (!_formKey.currentState!.validate()) return;

    final item = order_model.OrderItem(
      id: _selectedItem?.id ?? '',
      sku: _skuController.text.trim(),
      name: _nameController.text.trim(),
      quantity: int.parse(_quantityController.text),
      location: _locationController.text.trim(),
      barcode: _barcodeController.text.trim().isNotEmpty ? _barcodeController.text.trim() : null,
    );

    widget.onItemAdded(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialItem == null ? 'Add Item' : 'Edit Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchItemByBarcode(_barcodeController.text),
                        ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter barcode';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                enabled: false, // Make SKU field read-only
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveItem,
          child: const Text('Save'),
        ),
      ],
    );
  }
} 