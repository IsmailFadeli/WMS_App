import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // For context.pop()
import 'package:cloud_firestore/cloud_firestore.dart'; // Import cloud_firestore for FieldValue
import '../../providers/item_providers.dart'; // To access FirestoreService provider

// Import the Item model if needed for type hints, though not strictly necessary for saving map
// import '../../models/item.dart';


class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers for form fields
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _imageUrlController = TextEditingController(); // Add controller for image URL

  // State variable for loading indicator
  bool _isLoading = false;

  @override
  void dispose() {
    // Dispose controllers when the widget is removed
    _nameController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _barcodeController.dispose();
    _imageUrlController.dispose(); // Dispose image URL controller
    super.dispose();
  }

  // Function to handle saving the item
  Future<void> _saveItem() async {
    // Validate the form using the GlobalKey
    if (_formKey.currentState?.validate() ?? false) {
      // Set loading state
      setState(() {
        _isLoading = true;
      });

      // Try parsing quantity, handle potential format errors
      final int? quantity = int.tryParse(_quantityController.text);
      if (quantity == null) {
         setState(() { _isLoading = false; });
         // Check if widget is still mounted before showing SnackBar
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Invalid quantity. Please enter a valid number.')),
           );
         }
         return; // Stop execution if quantity is not a valid number
      }

      // Create a map of the data to be saved to Firestore.
      // Firestore will automatically generate the document ID.
      final newItemData = {
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'quantity': quantity,
        'location': _locationController.text.trim(),
        'barcode': _barcodeController.text.trim(), // Include barcode
        'imageUrl': _imageUrlController.text.trim(), // Include image URL
        // Add a server timestamp for when the item was created
        'createdAt': FieldValue.serverTimestamp(),
      };


      try {
        // Access the FirestoreService via Riverpod using ref.read for one-off actions
        // Call the addItemMap method (ensure this method exists in your service)
        await ref.read(firestoreServiceProvider).addItemMap(newItemData);


        // Check if the widget is still mounted before showing SnackBar or popping route
        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!')),
        );
        // Go back to the previous screen (HomeScreen)
        context.pop();

      } catch (e) {
         // If an error occurs during saving
         if (mounted) { // Check if widget is still mounted
           // Set loading state back to false
           setState(() { _isLoading = false; });
           // Show error message
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error adding item: $e')),
           );
         }
      }
      // No finally block needed for isLoading, as it's handled in success (pop) or error paths.
    } // End form validation check
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Item'),
        // Optional: Add a cancel button that pops the screen
        // leading: IconButton(
        //   icon: const Icon(Icons.close),
        //   onPressed: () => context.pop(),
        // ),
      ),
      // Use SingleChildScrollView to prevent overflow when keyboard appears
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Associate the GlobalKey with the Form
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Make elements stretch horizontally
            children: <Widget>[
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                textInputAction: TextInputAction.next, // Move focus to next field on enter/next
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the item name';
                  }
                  return null; // Return null if validation passes
                },
              ),
              const SizedBox(height: 16.0), // Spacing

              // SKU Field
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(labelText: 'SKU (Stock Keeping Unit)'),
                 textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the SKU';
                  }
                  // Add more specific SKU validation if needed (e.g., format, uniqueness check)
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

               // Barcode Field (Added)
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode (Optional)'),
                 textInputAction: TextInputAction.next,
                 // Barcode might be optional, so no validator or a simpler one
                 // validator: (value) {
                 //   if (value == null || value.trim().isEmpty) {
                 //     return 'Please enter the barcode';
                 //   }
                 //   return null;
                 // },
              ),
              const SizedBox(height: 16.0),


              // Quantity Field
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number, // Show number keyboard
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly // Allow only digits
                ],
                 textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                   if (int.parse(value) < 0) {
                     return 'Quantity cannot be negative';
                   }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // Location Field
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location (e.g., A1-S2-B3)'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the location';
                  }
                  return null;
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
                textInputAction: TextInputAction.done,
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

              const SizedBox(height: 32.0), // Larger spacing before button

              // Save Button
              // Show loading indicator if saving, otherwise show button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Item'),
                      onPressed: _saveItem, // Call the save function when pressed
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        textStyle: const TextStyle(fontSize: 16.0),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
