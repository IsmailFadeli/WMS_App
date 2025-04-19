import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart'; // Import the Item model
import '../services/firestore_service.dart'; // Import the FirestoreService

// Provider for the FirestoreService instance
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// StreamProvider that provides the list of inventory items
final itemsProvider = StreamProvider<List<Item>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getItemsStream();
});

// FutureProvider Family to fetch a single item by its ID
// '.family' allows passing an argument (the item ID) to the provider
final itemProvider = FutureProvider.family<Item?, String>((ref, itemId) async {
  // Watch the FirestoreService provider to get the instance
  final firestoreService = ref.watch(firestoreServiceProvider);
  // Call the service method to get the specific item
  return firestoreService.getItem(itemId);
});
