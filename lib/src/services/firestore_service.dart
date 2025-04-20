import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/item.dart'; // Import the Item model (ensure path is correct)
import 'package:flutter/foundation.dart'; // For kDebugMode
import '../models/order.dart';
import '../models/picker.dart';

/// Service class for interacting with the Firestore database, specifically the 'items' collection.
class FirestoreService {
  // Get the Firestore instance
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Reference to the 'items' collection WITH converter (primarily for reading/streaming Item objects)
  late final CollectionReference<Item> _itemsCollectionWithConverter;

  // Reference to the raw 'items' collection WITHOUT converter (for writing/updating Maps)
  late final CollectionReference<Map<String, dynamic>> _itemsCollectionRaw;

  // Collection references
  CollectionReference get _itemsCollection => _db.collection('items');
  CollectionReference get _ordersCollection => _db.collection('orders');

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

  /// Adds a new item to the Firestore database
  Future<void> addItem(Item item) async {
    try {
      final itemData = item.toMap();
      itemData['createdAt'] = FieldValue.serverTimestamp();
      await _itemsCollectionRaw.add(itemData);
    } catch (e) {
      throw Exception('Failed to add item: $e');
    }
  }

  // Generate a unique order number
  String _generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(8); // Use last 5 digits
    return 'SO-${now.year}-$timestamp';
  }

  // Create a new store order
  Future<String> createStoreOrder(Order order) async {
    try {
      final orderData = order.toFirestore();
      // Ensure it's a store order
      orderData['type'] = 'store';
      // Generate order number if not provided
      if (orderData['orderNumber'] == null || orderData['orderNumber'].isEmpty) {
        orderData['orderNumber'] = _generateOrderNumber();
      }
      // Add timestamps
      orderData['createdAt'] = FieldValue.serverTimestamp();
      orderData['updatedAt'] = FieldValue.serverTimestamp();

      // Create the order document
      final docRef = await _ordersCollection.add(orderData);
      
      // Update inventory quantities
      for (final item in order.items) {
        // Get the item document to verify location
        final itemDoc = await _itemsCollection.doc(item.id).get();
        if (!itemDoc.exists) {
          throw Exception('Item ${item.id} not found in inventory');
        }
        
        // Verify item location matches
        final itemData = itemDoc.data() as Map<String, dynamic>;
        if (itemData['location'] != item.location) {
          throw Exception('Location mismatch for item ${item.id}. Expected: ${itemData['location']}, Got: ${item.location}');
        }

        // Update quantity if location is correct
        await _itemsCollection.doc(item.id).update({
          'quantity': FieldValue.increment(-item.quantity)
        });
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create store order: $e');
    }
  }

  // Get all store orders
  Stream<List<Order>> getStoreOrders() {
    if (kDebugMode) {
      print('Getting store orders stream...');
    }
    return _ordersCollection
        .where('type', isEqualTo: 'store')
        .where('status', isNull: false)  // Include all statuses
        .orderBy('status', descending: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            print('Received ${snapshot.docs.length} orders from Firestore');
            for (var doc in snapshot.docs) {
              try {
                print('Raw Order Data - ID: ${doc.id}');
                print('Document data: ${doc.data()}');
                
                // Try to convert each document
                final order = Order.fromFirestore(doc);
                print('Successfully converted order: #${order.orderNumber}');
              } catch (e) {
                print('Error converting order document ${doc.id}: $e');
              }
            }
          }
          
          // Now do the actual conversion
          final orders = snapshot.docs.map((doc) {
            try {
              return Order.fromFirestore(doc);
            } catch (e) {
              print('Error converting order ${doc.id}: $e');
              rethrow;
            }
          }).toList();
          
          return orders;
        })
        .handleError((error) {
          if (kDebugMode) {
            print('Error in getStoreOrders stream: $error');
          }
          throw error;
        });
  }

  // Get a specific order
  Stream<Order?> getOrder(String orderId) {
    return getOrderStream(orderId);
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  // Cancel order and restore inventory
  Future<void> cancelOrder(String orderId) async {
    try {
      // Get the order first
      final orderDoc = await _ordersCollection.doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final order = Order.fromFirestore(orderDoc);
      
      // Start a batch write
      final batch = _db.batch();

      // Update order status
      batch.update(_ordersCollection.doc(orderId), {
        'status': OrderStatus.cancelled.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Restore inventory quantities
      for (final item in order.items) {
        batch.update(_itemsCollection.doc(item.id), {
          'quantity': FieldValue.increment(item.quantity)
        });
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  // Delete order (only if cancelled)
  Future<void> deleteOrder(String orderId) async {
    try {
      final orderDoc = await _ordersCollection.doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final order = Order.fromFirestore(orderDoc);
      if (order.status != OrderStatus.cancelled) {
        throw Exception('Only cancelled orders can be deleted');
      }

      await _ordersCollection.doc(orderId).delete();
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  /// Cancel a store order by updating its status to cancelled
  Future<void> cancelStoreOrder(String orderId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling order: $e');
      }
      throw Exception('Failed to cancel order: $e');
    }
  }

  /// Delete a store order that has been cancelled
  Future<void> deleteStoreOrder(String orderId) async {
    try {
      // First verify the order is cancelled
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }
      
      final orderData = orderDoc.data() as Map<String, dynamic>;
      if (orderData['status'] != 'cancelled') {
        throw Exception('Only cancelled orders can be deleted');
      }

      // Delete the order
      await _db.collection('orders').doc(orderId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting order: $e');
      }
      throw Exception('Failed to delete order: $e');
    }
  }

  // Get a stream of a single order
  Stream<Order?> getOrderStream(String orderId) {
    return _ordersCollection
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? Order.fromFirestore(doc) : null);
  }

  // Get scanned items for an order
  Future<Map<String, int>> getScannedItems(String orderId) async {
    try {
      final doc = await _ordersCollection.doc(orderId).get();
      if (!doc.exists) {
        return {};
      }
      final data = doc.data() as Map<String, dynamic>;
      final scannedItems = data['scannedItems'] as Map<String, dynamic>? ?? {};
      return Map<String, int>.from(scannedItems);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting scanned items: $e');
      }
      return {};
    }
  }

  // Update scanned items for an order
  Future<void> updateScannedItems(String orderId, Map<String, int> scannedItems) async {
    try {
      await _ordersCollection.doc(orderId).update({
        'scannedItems': scannedItems,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating scanned items: $e');
      }
      rethrow;
    }
  }

  // Update order fields
  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _ordersCollection.doc(orderId).update(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating order $orderId: $e');
      }
      throw Exception('Failed to update order: $e');
    }
  }

  // Picker methods
  Stream<List<Picker>> getPickers() {
    return _db.collection('pickers').snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Picker.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Get a single picker
  Future<Picker?> getPicker(String id) async {
    final doc = await _db.collection('pickers').doc(id).get();
    if (!doc.exists) return null;
    return Picker.fromMap(doc.data()!, doc.id);
  }

  // Add a new picker
  Future<void> addPicker(Map<String, dynamic> data) async {
    await _db.collection('pickers').add(data);
  }

  // Delete a picker
  Future<void> deletePicker(String id) async {
    await _db.collection('pickers').doc(id).delete();
  }

  // Update order with picker information
  Future<void> updateOrderWithPicker(String orderId, Picker picker) async {
    await _db.collection('orders').doc(orderId).update({
      'pickerId': picker.id,
      'pickerName': picker.name,
      'pickerSurname': picker.surname,
    });
  }

  // Complete an order
  Future<void> completeOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': OrderStatus.completed.toString().split('.').last,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
