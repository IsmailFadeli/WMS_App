import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart'; // Import the Item model (ensure path is correct)
import 'package:flutter/foundation.dart'; // For kDebugMode

/// Service class for interacting with the Firestore database, specifically the 'items' collection.
class FirestoreService {
  // Get the Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Reference to the 'items' collection WITH converter (primarily for reading/streaming Item objects)
  late final CollectionReference<Item> _itemsCollectionWithConverter;

  // Reference to the raw 'items' collection WITHOUT converter (for writing/updating Maps)
  late final CollectionReference<Map<String, dynamic>> _itemsCollectionRaw;


  FirestoreService() {
    // Initialize collection reference with the converter for reading
    _itemsCollectionWithConverter = _db.collection('items').withConverter<Item>(
          // Define how to convert Firestore data to an Item object
          fromFirestore: (snapshot, _) => Item.fromFirestore(snapshot),
          // Define how to convert an Item object back to Firestore data
          // We remove this as our write methods use Maps directly via _itemsCollectionRaw
          // This avoids errors if Item model doesn't have a matching toJson()
          toFirestore: (item, _) => {}, // Provide an empty map or handle appropriately if needed
                                        // Alternatively, remove this line if never using the converter for writes.
                                        // Let's provide an empty map for safety, though it won't be used by our methods.
        );
    // Initialize raw collection reference for writes/updates
     _itemsCollectionRaw = _db.collection('items');
  }

  /// Provides a continuous stream of the list of inventory items.
  /// Uses the converter to automatically map snapshots to Item objects.
  Stream<List<Item>> getItemsStream() {
    return _itemsCollectionWithConverter
        // Optional: Order items, e.g., by creation time or name
        .orderBy('createdAt', descending: true)
        .snapshots() // Listen to real-time updates
        .map((snapshot) {
          // Map the QuerySnapshot to a List<Item>
          try {
            // The converter handles the data extraction and Item creation
            return snapshot.docs.map((doc) => doc.data()).toList();
          } catch (e) {
             if (kDebugMode) {
               // Consider logging the specific document ID if possible
               print('Error mapping Firestore snapshot to List<Item>: $e');
             }
             return <Item>[]; // Return empty list on error during mapping
          }
        })
        .handleError((error, stackTrace) {
          // Handle errors in the stream itself (e.g., permission denied)
          if (kDebugMode) {
            print("Error fetching items stream: $error");
            print(stackTrace);
          }
          // Let the error propagate so UI layer (StreamProvider) can handle it
          throw error;
        });
  }

  /// Adds a new item document to the Firestore 'items' collection using a Map.
  /// Uses the raw collection reference.
  Future<void> addItemMap(Map<String, dynamic> itemData) async {
    try {
      // Ensure createdAt timestamp is added if not present
      itemData.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
      // Use the raw collection reference to add the map directly
      await _itemsCollectionRaw.add(itemData);
      if (kDebugMode) {
        print("Item added successfully via Map: ${itemData['sku']}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error adding item via Map: $e");
      }
      rethrow; // Re-throw the error for the UI layer to handle
    }
  }

  /// Fetches a single item document by its ID.
  /// Uses the converter to return an Item object.
  /// Returns null if the document doesn't exist or an error occurs.
  Future<Item?> getItem(String docId) async {
    if (docId.isEmpty) return null; // Basic check for empty ID
    try {
      // Use the collection reference with the converter
      final snapshot = await _itemsCollectionWithConverter.doc(docId).get();
      if (snapshot.exists) {
        // The converter automatically provides the Item object via .data()
        return snapshot.data();
      } else {
        if (kDebugMode) {
          print("Document with ID $docId does not exist.");
        }
        return null; // Document not found
      }
    } catch (e) {
       if (kDebugMode) {
         print("Error fetching document $docId: $e");
       }
       return null; // Return null on error
    }
  }

  /// Updates an existing item document in Firestore using a Map of data.
  /// Uses the raw collection reference.
  Future<void> updateItem(String docId, Map<String, dynamic> data) async {
     if (docId.isEmpty) return; // Basic check
     try {
      // Add server timestamp for update automatically
      data['lastUpdatedAt'] = FieldValue.serverTimestamp();
      // Use the raw collection reference to update with the map
      await _itemsCollectionRaw.doc(docId).update(data);
       if (kDebugMode) {
         print("Item $docId updated successfully.");
       }
    } catch (e) {
       if (kDebugMode) {
         print("Error updating item $docId: $e");
       }
       rethrow; // Re-throw the error for the UI layer to handle
    }
  }

  /// Deletes an item document from Firestore by its ID.
  /// Uses the raw collection reference.
  Future<void> deleteItem(String docId) async {
    if (docId.isEmpty) return; // Basic check
    try {
      // Use the raw collection reference to delete
      await _itemsCollectionRaw.doc(docId).delete();
       if (kDebugMode) {
         print("Item $docId deleted successfully.");
       }
    } catch (e) {
       if (kDebugMode) {
         print("Error deleting item $docId: $e");
       }
       rethrow; // Re-throw the error for the UI layer to handle
    }
  }
}
