import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // For context.pop()
import 'package:cloud_firestore/cloud_firestore.dart'; // For FieldValue (though update timestamp is handled by service now)
import '../../providers/item_providers.dart'; // To access FirestoreService and itemProvider
import '../../models/item.dart'; // Import the Item model (ensure it has barcode as String?)

class EditItemScreen extends ConsumerStatefulWidget {
  final String itemId; // Receive item ID from router

  const EditItemScreen({required this.itemId, super.key});

  @override
  ConsumerState<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends ConsumerState<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _quantityController;
  late TextEditingController _locationController;
  late TextEditingController _barcodeController;
  late TextEditingController _imageUrlController;

  bool _isLoading = false;
  bool _isInitialized = false; // Flag to prevent re-initializing controllers

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _skuController = TextEditingController();
    _quantityController = TextEditingController();
    _locationController = TextEditingController();
    _barcodeController = TextEditingController();
    _imageUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _barcodeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  // Function to initialize controllers with item data
  void _initializeControllers(Item item) {
    // Check the flag to ensure this runs only once per data load
    if (!_isInitialized && mounted) {
      _nameController.text = item.name;
      _skuController.text = item.sku;
      _quantityController.text = item.quantity.toString();
      _locationController.text = item.location;
      _barcodeController.text = item.barcode ?? '';
      _imageUrlController.text = item.imageUrl ?? '';
      setState(() {
         _isInitialized = true; // Set flag after initialization
      });
    }
  }

  // Function to handle updating the item
  Future<void> _updateItem() async {
    // Ensure controllers are initialized before attempting to save
    if (!_isInitialized) return;

    if (_formKey.currentState?.validate() ?? false) {
      setState(() { _isLoading = true; });

      // Parse Quantity (still needed)
      final int? quantity = int.tryParse(_quantityController.text);
      if (quantity == null) {
         setState(() { _isLoading = false; });
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Invalid quantity.')),
           );
         }
         return;
      }

      // Get barcode directly as String (handle empty string if needed)
      final String barcodeInput = _barcodeController.text.trim();

      // Create map of updated data, including barcode String?
      final updatedData = {
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(), // Include SKU even if read-only in form
        'quantity': quantity, // Keep quantity as int
        'location': _locationController.text.trim(),
        'barcode': barcodeInput.isEmpty ? null : barcodeInput, // Save String, or null if empty
        'imageUrl': _imageUrlController.text.trim(),
        // 'lastUpdatedAt' field is added automatically by the service method
      };

      try {
        // Call the updateItem method from FirestoreService
        await ref.read(firestoreServiceProvider).updateItem(widget.itemId, updatedData);

        if (!mounted) return; // Check if widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully!')),
        );
        context.pop(); // Go back after successful update

      } catch (e) {
         if (mounted) { // Check if widget is still mounted
           setState(() { _isLoading = false; });
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error updating item: $e')),
           );
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the specific item provider using the itemId passed to the widget
    final itemAsyncValue = ref.watch(itemProvider(widget.itemId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Item'),
      ),
      // Use .when to handle the async states of fetching the item
      body: itemAsyncValue.when(
        // Data loaded successfully state
        data: (item) {
          // If item data exists, initialize controllers (if not already done) and show form
          if (item != null) {
            // Initialize controllers safely after the first frame renders
            // Use addPostFrameCallback to avoid calling setState during build
             WidgetsBinding.instance.addPostFrameCallback((_) {
                _initializeControllers(item);
             });

            // Build the form UI only after initialization attempt
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Display SKU (Read-only)
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        // Indicate read-only visually if desired
                        // filled: true,
                        // fillColor: Colors.grey[200],
                      ),
                      readOnly: true, // Make SKU non-editable in the form
                    ),
                    const SizedBox(height: 16.0),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                         if (value == null || value.trim().isEmpty) { return 'Please enter the item name'; } return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                     // Barcode Field (Handles String)
                    TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(labelText: 'Barcode (Optional)'),
                      keyboardType: TextInputType.text, // Default keyboard for string
                      inputFormatters: const [], // No specific formatters needed
                      textInputAction: TextInputAction.next,
                      // No specific validation needed unless required (e.g., length)
                    ),
                    const SizedBox(height: 16.0),

                    // Quantity Field (Handles int)
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                         if (value == null || value.isEmpty) { return 'Please enter the quantity'; } if (int.tryParse(value) == null) { return 'Please enter a valid number'; } if (int.parse(value) < 0) { return 'Quantity cannot be negative'; } return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Location Field
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                      textInputAction: TextInputAction.done,
                      // Update item when 'done' is pressed on keyboard if not loading
                      onFieldSubmitted: (_) => _isLoading ? null : _updateItem(),
                      validator: (value) {
                         if (value == null || value.trim().isEmpty) { return 'Please enter the location'; } return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Image URL Field
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (Optional)',
                        hintText: 'https://example.com/image.jpg',
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (value) {
                        // Trigger rebuild to update image preview
                        if (mounted) setState(() {});
                      },
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final urlPattern = RegExp(
                            r'^https?:\/\/([\w-]+\.)+[\w-]+(\/[\w- .\/?%&=]*)?$',
                            caseSensitive: false,
                          );
                          if (!urlPattern.hasMatch(value)) {
                            return 'Please enter a valid URL';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Image Preview
                    if (_imageUrlController.text.isNotEmpty) ...[
                      Container(
                        constraints: const BoxConstraints(
                          maxHeight: 300,
                          maxWidth: 400,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _imageUrlController.text,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 300,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Invalid image URL',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 300,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    const SizedBox(height: 32.0),

                    // Update Button - show only if controllers are initialized
                    _isInitialized
                      ? (_isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('Save Changes'),
                              onPressed: _updateItem, // Call update function
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                textStyle: const TextStyle(fontSize: 16.0),
                              ),
                            )
                          )
                      // Show loading indicator or placeholder while initializing
                      : const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                  ],
                ),
              ),
            );
          } else {
            // Item not found state (after loading finished but item is null)
            return const Center(
              child: Text('Item not found or could not be loaded.'),
            );
          }
        },
        // Error state while fetching item
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading item details: $error'),
          ),
        ),
        // Loading state while fetching item
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
