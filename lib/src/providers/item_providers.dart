import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart'; // Import the Item model
import '../services/firestore_service.dart'; // Import the FirestoreService
import '../models/order.dart';
import 'package:flutter/foundation.dart';

// Provider for the FirestoreService instance
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// Stream provider for all inventory items
final inventoryStreamProvider = StreamProvider<List<Item>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getItemsStream();
});

// Provider for a single item by ID
final itemProvider = StreamProvider.family<Item?, String>((ref, itemId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getItem(itemId).asStream();
});

// Stream provider for store orders
final storeOrdersProvider = StreamProvider<List<Order>>((ref) {
  if (kDebugMode) {
    print('Initializing store orders provider');
  }
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getStoreOrders();
});

// Stream provider for a single order by ID
final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getOrder(orderId);
});
