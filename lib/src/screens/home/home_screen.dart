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

// --- Project Specific Imports ---
// Ensure these paths match your project structure
import '../../providers/auth_providers.dart' show authServiceProvider;
import '../../providers/item_providers.dart' show itemsProvider, firestoreServiceProvider;
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


  @override
  Widget build(BuildContext context) {
    // Watch necessary providers
    final itemsAsyncValue = ref.watch(itemsProvider);
    final authService = ref.watch(authServiceProvider);
    final firestoreService = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WMS Dashboard - Inventory'),
        actions: [
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
      body: Center(
        // Handle stream states: loading, error, data
        child: itemsAsyncValue.when(
          data: (items) {
            // Apply filtering based on search query using arrow function
            _filteredItems = items.where((item) {
              // Pre-calculate lowercase values for efficiency and clarity
              final query = _searchQuery.toLowerCase();
              final sku = item.sku.toLowerCase();
              final barcode = item.barcode?.toLowerCase() ?? ''; // Handle null barcode safely
              // Return true if SKU or Barcode contains the query
              return sku.contains(query) || (barcode.isNotEmpty && barcode.contains(query));
            }).toList(); // Convert the filtered results to a List


            // Handle empty states (no items at all vs. no search results)
            if (_filteredItems.isEmpty) {
              if (items.isEmpty) {
                // No items in the database
                return const Center(
                  child: Text(
                    'No inventory items found.\nTap the "+" button below to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              } else {
                 // No items match the current search query
                 return Center(
                  child: Text(
                    'No items match your search "$_searchQuery".',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }
            }

            // DataTable display (remains the same)
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 padding: const EdgeInsets.all(16.0),
                 child: DataTable(
                  columns: const <DataColumn>[
                     DataColumn(label: Text('SKU')),
                     DataColumn(label: Text('Name')),
                     DataColumn(label: Text('Quantity'), numeric: true),
                     DataColumn(label: Text('Location')),
                     DataColumn(label: Text('Barcode')),
                     DataColumn(label: Text('Actions')),
                  ],
                  rows: _filteredItems.map((item) {
                    if (item.id == null) {
                       print("Error: Item found with null ID: ${item.name}");
                       return const DataRow(cells: [
                         DataCell(Text("Error")), DataCell(Text("Invalid")), DataCell(Text("")),
                         DataCell(Text("")), DataCell(Text("")), DataCell(Text("")),
                       ]);
                    }
                    return DataRow(
                       cells: <DataCell>[
                         DataCell(Text(item.sku)),
                         DataCell(Text(item.name)),
                         DataCell(Text(item.quantity.toString())),
                         DataCell(Text(item.location)),
                         DataCell(Text(item.barcode ?? '')), // Handle null barcode
                         // Actions cell with Edit/Delete buttons
                         DataCell(
                           Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               // Edit Button
                               IconButton(
                                 icon: const Icon(Icons.edit, size: 20),
                                 tooltip: 'Edit Item',
                                 onPressed: () {
                                   context.pushNamed(
                                     AppRoutes.editItem,
                                     pathParameters: {'itemId': item.id!},
                                   );
                                 },
                                 constraints: const BoxConstraints(),
                                 padding: const EdgeInsets.symmetric(horizontal: 8),
                               ),
                               // Delete Button
                               IconButton(
                                 icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                                 tooltip: 'Delete Item',
                                 onPressed: () async {
                                   final confirm = await _showDeleteConfirmationDialog(context, item.name);
                                   if (confirm == true) {
                                     try {
                                       await firestoreService.deleteItem(item.id!);
                                       if (context.mounted) {
                                         ScaffoldMessenger.of(context).showSnackBar(
                                           SnackBar(content: Text('Item "${item.name}" deleted.'), backgroundColor: Colors.green),
                                         );
                                       }
                                     } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error deleting item: $e'), backgroundColor: Theme.of(context).colorScheme.error),
                                          );
                                        }
                                     }
                                   }
                                 },
                                 constraints: const BoxConstraints(),
                                 padding: const EdgeInsets.symmetric(horizontal: 8),
                               ),
                             ],
                           )
                         ),
                       ],
                     );
                  }).toList(),
                  // Optional DataTable styling
                  headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) => Colors.blueGrey.shade100,
                  ),
                  border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                  dataRowMinHeight: 48,
                  headingRowHeight: 56,
                 ),
              ),
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
      // FAB section (remains the same)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () { context.pushNamed(AppRoutes.addItem); },
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        tooltip: 'Add New Inventory Item',
      ),
    );
  }
}
