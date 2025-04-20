import 'dart:io'; // Required for File operations (non-web)
// Conditional import for dart:html, only available on web
import 'dart:html' as html; // Use prefix to avoid conflicts
import 'dart:async'; // Import for Future.delayed
import 'package:flutter/foundation.dart' show kIsWeb; // To check if running on web
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // For navigation
import 'package:excel/excel.dart'; // For Excel generation
import 'package:share_plus/share_plus.dart'; // For sharing files (non-web)
import 'package:path_provider/path_provider.dart'; // For temporary directory (non-web)
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp; // For Timestamp

// --- Project Specific Imports ---
// Ensure these paths match your project structure
import '../../providers/auth_providers.dart' show authServiceProvider;
import '../../providers/item_providers.dart' show inventoryStreamProvider, firestoreServiceProvider;
import '../../models/item.dart'; // Your data model for items
import '../../routing/app_router.dart'; // Your route definitions


/// Helper function specifically for triggering a file download on the web.
/// Moved outside the state class to minimize potential state interactions.
Future<void> _triggerWebDownload(List<int> bytes, String filename) async {
  // Create blob from bytes
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  // Create an object URL from the blob.
  final url = html.Url.createObjectUrlFromBlob(blob);
  // Create an anchor element (<a>)
  final anchor = html.AnchorElement(href: url)
    // Set the download attribute to suggest a filename
    ..setAttribute("download", filename);

  // Add a tiny delay before clicking - sometimes helps with browser event loops
  await Future.delayed(const Duration(milliseconds: 50));

  // Programmatically click the anchor element to trigger the download.
  anchor.click();

  // Release the object URL to free up memory.
  html.Url.revokeObjectUrl(url);
}


/// HomeScreen Widget: Main dashboard with inventory display, search, actions,
/// and platform-aware export functionality.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// State class for HomeScreen. Manages search query and filtered item list.
class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Controller for the search input field.
  final TextEditingController _searchController = TextEditingController();
  // Holds the current search query entered by the user.
  String _searchQuery = '';
  // Holds the list of items after applying the search filter. Used for display and export.
  List<Item> _filteredItems = [];
  // Flag to prevent multiple simultaneous export operations (debouncing).
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    // Listen for changes in the search field and update the state.
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        // Filtering logic is applied during the build phase.
      });
    });
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _searchController.dispose();
    super.dispose();
  }

  /// Shows a confirmation dialog before deleting an item.
  Future<bool?> _showDeleteConfirmationDialog(BuildContext context, String itemName) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the item "$itemName"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Return false on cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red), // Destructive action style
              onPressed: () => Navigator.of(dialogContext).pop(true), // Return true on confirm
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a confirmation dialog before logging out.
  Future<bool?> _showLogoutConfirmationDialog(BuildContext context) {
     return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Return false on cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Return true on confirm
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  /// Shows a dialog with item details
  void _showItemDetailsDialog(Item item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 300,
                      maxWidth: 400,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl!,
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
                                  'Failed to load image',
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
                ),
                const SizedBox(height: 16),
              ],
              _detailRow('SKU', item.sku),
              _detailRow('Name', item.name),
              _detailRow('Quantity', item.quantity.toString()),
              _detailRow('Location', item.location),
              if (item.barcode != null && item.barcode!.isNotEmpty)
                _detailRow('Barcode', item.barcode!),
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                _detailRow('Image URL', item.imageUrl!),
              if (item.createdAt != null)
                _detailRow('Created', _formatTimestamp(item.createdAt!)),
              if (item.lastUpdatedAt != null)
                _detailRow('Last Updated', _formatTimestamp(item.lastUpdatedAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Format Timestamp to readable date string
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Helper method to create consistent detail rows
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label + ':',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generates an Excel file from the item list and handles export/download.
  /// Includes debouncing and uses a separate helper for web download.
  Future<void> _exportToExcel(BuildContext context, List<Item> itemsToExport) async {
    // Debouncing check: If already exporting, do nothing.
    if (_isExporting) return;

    // Set the flag to true to indicate export has started.
    _isExporting = true;
    // Disable button via build check using this flag

    // Use a try...finally block to ensure the flag is reset even if errors occur.
    try {
      // Check if there's anything to export
      if (itemsToExport.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No items to export.'),
            backgroundColor: Colors.orange,
          ),
        );
         _isExporting = false; // Reset flag before early return
        return;
      }

      // Show loading indicator
      if (!context.mounted) return;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator())
      );

      // --- Start Export Logic ---
      // (Excel generation logic remains the same)
      final excel = Excel.createExcel();
      final Sheet sheet = excel[excel.getDefaultSheet()!];
      sheet.appendRow([
         TextCellValue('SKU'),  TextCellValue('Name'),  TextCellValue('Quantity'),
         TextCellValue('Location'),  TextCellValue('Barcode'),
      ]);
      for (final item in itemsToExport) {
        sheet.appendRow([
          TextCellValue(item.sku), TextCellValue(item.name), IntCellValue(item.quantity),
          TextCellValue(item.location), TextCellValue(item.barcode ?? ''),
        ]);
      }
      final fileBytes = excel.save();
      // --- End Excel generation logic ---


      if (fileBytes != null) {
        // Dismiss loading indicator *before* triggering download/share
        if (context.mounted) Navigator.of(context).pop();

        // --- Platform Specific Handling ---
        if (kIsWeb) {
          // WEB: Call the separate helper function
          await _triggerWebDownload(fileBytes, "inventory_export_${DateTime.now().millisecondsSinceEpoch}.xlsx");
          if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Excel file download started.'), backgroundColor: Colors.green)
              );
          }
        } else {
          // MOBILE/DESKTOP: Save temporarily and share
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/inventory_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
          final file = File(filePath)..writeAsBytesSync(fileBytes);
          final xFile = XFile(file.path);
          await Share.shareXFiles(
              [xFile], text: 'Here is the inventory export.',
              subject: 'Inventory Export ${DateTime.now().toLocal().toString().split(' ')[0]}'
          );
        }
        // --- End Platform Specific Handling ---

      } else {
         // Handle encoding failure
         if (context.mounted) Navigator.of(context).pop(); // Ensure dialog is closed
         throw Exception("Failed to encode Excel file bytes.");
      }
      // --- End Export Logic ---

    } catch (e) {
       // Handle any errors during the process
       // Ensure dialog is closed if it was opened
       if (Navigator.of(context).canPop()) {
           Navigator.of(context).pop();
       }
       if (!context.mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error exporting to Excel: $e'),
           backgroundColor: Theme.of(context).colorScheme.error,
         ),
       );
    } finally {
      // Reset the flag when the export process finishes (or fails).
      // Use setState here to ensure the button is re-enabled visually.
      if (mounted) {
          setState(() {
            _isExporting = false;
          });
      } else {
        // If not mounted, just ensure the flag is reset logically
        _isExporting = false;
      }
    }
  }

  /// Handles importing items from an Excel file
  Future<void> _importFromExcel() async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
    });

    try {
      // Show loading indicator
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading indicator

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes == null) {
          throw Exception('Could not read file');
        }

        // Parse Excel file
        final excel = Excel.decodeBytes(bytes);
        final Sheet? sheet = excel.tables[excel.tables.keys.first];
        
        if (sheet == null) {
          throw Exception('No sheet found in Excel file');
        }

        // Skip header row and process data
        final firestoreService = ref.read(firestoreServiceProvider);
        int successCount = 0;
        List<String> errors = [];

        // Process all items first
        List<Future<void>> addFutures = [];

        // Assuming first row is header, start from index 1
        for (int row = 1; row < sheet.rows.length; row++) {
          try {
            final rowData = sheet.rows[row];
            if (rowData.isEmpty || rowData[0]?.value == null) continue;

            final item = Item(
              id: '', // Empty string instead of null
              sku: rowData[0]?.value.toString().trim() ?? '',
              name: rowData[1]?.value.toString().trim() ?? '',
              quantity: int.tryParse(rowData[2]?.value.toString().trim() ?? '0') ?? 0,
              location: rowData[3]?.value.toString().trim() ?? '',
              barcode: rowData[4]?.value?.toString()?.trim(),
              imageUrl: rowData[5]?.value?.toString()?.trim(), // Add image URL column
            );

            // Validate required fields
            if (item.sku.isEmpty || item.name.isEmpty) {
              errors.add('Row ${row + 1}: SKU and Name are required');
              continue;
            }

            // Add to futures list instead of awaiting immediately
            addFutures.add(
              firestoreService.addItem(item)
                .then((_) => successCount++)
                .catchError((e) {
                  errors.add('Row ${row + 1}: Failed to add item - ${e.toString()}');
                  return null;
                })
            );
          } catch (e) {
            errors.add('Row ${row + 1}: ${e.toString()}');
          }
        }

        // Wait for all items to be added
        await Future.wait(addFutures, eagerError: false);

        // Force refresh the items list
        if (mounted) {
          // Invalidate the provider and rebuild
          ref.invalidate(inventoryStreamProvider);
          setState(() {}); // Rebuild UI()
        }

        // Show results with more informative message
      
        if (!context.mounted) return;
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Import completed: $successCount items added successfully' +
                (errors.isNotEmpty ? ' (with ${errors.length} errors)' : '')
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
              action: errors.isNotEmpty
                ? SnackBarAction(
                    label: 'Show Errors',
                    onPressed: () => _showErrorDialog(errors),
                    textColor: Colors.white,
                  )
                : null,
            ),
          );
        } else if (errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Import failed: No items were added'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Show Errors',
                onPressed: () => _showErrorDialog(errors),
                textColor: Colors.white,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing file: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  /// Shows a dialog with import errors
  void _showErrorDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Errors'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors.map((error) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• $error'),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to edit the location of an item
  void _showEditLocationDialog(Item item) {
    final TextEditingController locationController = TextEditingController(text: item.location);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Location - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current location: ${item.location}'),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'New Location',
                hintText: 'Enter new location',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newLocation = locationController.text.trim();
              if (newLocation.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location cannot be empty')),
                );
                return;
              }
              
              try {
                final firestoreService = ref.read(firestoreServiceProvider);
                await firestoreService.updateItem(item.id, {'location': newLocation});
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Location updated for ${item.name}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating location: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch necessary providers with autoDispose to ensure fresh data
    final itemsAsyncValue = ref.watch(inventoryStreamProvider.select((value) => value));
    final authService = ref.watch(authServiceProvider);
    final firestoreService = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WMS Dashboard - Inventory'),
        actions: [
          // Orders Button
          IconButton(
            icon: const Icon(Icons.shopping_bag),
            tooltip: 'Orders',
            onPressed: () => context.push(AppRoutes.orders),
          ),
          // Import Button
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Excel',
            onPressed: _importFromExcel,
          ),
          // Export Button - Disable if export is in progress
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            // Conditionally disable onPressed if _isExporting is true
            onPressed: _isExporting ? null : () {
              _exportToExcel(context, _filteredItems);
            },
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await _showLogoutConfirmationDialog(context);
              if (confirm == true) {
                 await authService.signOut();
                 // Optional: Navigate after sign out
                 // if (context.mounted) context.go(AppRoutes.login);
              }
            },
          ),
        ],
        // Search bar section (remains the same)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by SKU or Barcode...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(230),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
        ),
      ),
      // Body section
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: Center(
              // Handle stream states: loading, error, data
              child: itemsAsyncValue.when(
                data: (items) {
                  // Only show results if there's a search query
                  if (_searchQuery.isEmpty) {
                    return const Center(
                      child: Text(
                        'Enter a SKU or Barcode to search inventory',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  // Apply filtering based on search query
                  _filteredItems = items.where((item) {
                    final query = _searchQuery.toLowerCase();
                    final sku = item.sku.toLowerCase();
                    final name = item.name.toLowerCase();
                    final barcode = item.barcode?.toLowerCase() ?? '';
                    return sku.contains(query) || 
                           name.contains(query) || 
                           (barcode.isNotEmpty && barcode.contains(query));
                  }).toList();

                  if (_filteredItems.isEmpty) {
                    return Center(
                      child: Text(
                        'No items match your search "$_searchQuery".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text('SKU: ${item.sku}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Qty: ${item.quantity}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () => _showItemDetailsDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditLocationDialog(item),
                              ),
                            ],
                          ),
                          onTap: () => _showItemDetailsDialog(item),
                        ),
                      );
                    },
                  );
                },
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading inventory items:\n$error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),

          // Bottom buttons row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.extended(
                  onPressed: () => context.pushNamed(AppRoutes.addItemName),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  heroTag: 'addItem',
                ),
                const SizedBox(width: 16), // Space between buttons
                FloatingActionButton.extended(
                  onPressed: () => context.push(AppRoutes.orders),
                  icon: const Icon(Icons.store),
                  label: const Text('Picking Orders'),
                  heroTag: 'orders',
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
