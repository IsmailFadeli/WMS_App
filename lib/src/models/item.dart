import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an inventory item in the warehouse.
class Item {
  final String id; // Firestore document ID
  final String name;
  final String sku;
  final int quantity;
  final String location;
  final String? barcode; // Changed back to nullable String
  final Timestamp? createdAt;
  final Timestamp? lastUpdatedAt;


  Item({
    required this.id,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.location,
    this.barcode, // Make barcode optional in constructor
    this.createdAt,
    this.lastUpdatedAt,
  });

  /// Creates an Item object from a Firestore document snapshot.
  factory Item.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    return Item(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Item',
      sku: data['sku'] as String? ?? 'No SKU',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0, // Keep quantity as int
      location: data['location'] as String? ?? 'Unknown Location',
      // Parse barcode as String?
      barcode: data['barcode'] as String?, // Read directly as String?
      createdAt: data['createdAt'] as Timestamp?,
      lastUpdatedAt: data['lastUpdatedAt'] as Timestamp?,
    );
  }

  /// Converts an Item object into a Map suitable for Firestore updates.
   Map<String, dynamic> toJsonForUpdate() {
    return {
      'name': name,
      'sku': sku,
      'quantity': quantity,
      'location': location,
      'barcode': barcode, // Include barcode String?
    };
  }

   /// Converts an Item object into a Map suitable for Firestore creation.
   Map<String, dynamic> toJsonForAdd() {
    return {
      'name': name,
      'sku': sku,
      'quantity': quantity,
      'location': location,
      'barcode': barcode, // Include barcode String?
    };
  }

  @override
  String toString() {
    // Updated toString to include barcode String?
    return 'Item(id: $id, name: $name, sku: $sku, quantity: $quantity, location: $location, barcode: $barcode)';
  }
}
