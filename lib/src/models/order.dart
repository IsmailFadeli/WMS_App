import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Represents the type of order (ecommerce or store)
enum OrderType { 
  ecommerce,  // Online orders
  store       // In-store orders
}

/// Represents the current status of an order
enum OrderStatus { 
  pending,     // Order just created
  processing,  // Order is being prepared
  ready,       // Order is ready for pickup/delivery
  completed,   // Order has been fulfilled
  cancelled    // Order was cancelled
}

/// Represents a single item in an order
class OrderItem {
  final String id;          // Unique identifier for the order item
  final String sku;         // Stock keeping unit
  final String name;        // Item name
  final int quantity;       // Quantity ordered
  final String location;    // Warehouse location
  final String? barcode;    // Barcode of the item

  OrderItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.location,
    this.barcode,
  });

  /// Creates an OrderItem from a Firestore document
  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      location: map['location'] as String? ?? '',
      barcode: map['barcode'] as String?,
    );
  }

  /// Converts the OrderItem to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'quantity': quantity,
      'location': location,
      'barcode': barcode,
    };
  }

  /// Creates a copy of this OrderItem with the given fields replaced
  OrderItem copyWith({
    String? id,
    String? sku,
    String? name,
    int? quantity,
    String? location,
    String? barcode,
  }) {
    return OrderItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      location: location ?? this.location,
      barcode: barcode ?? this.barcode,
    );
  }
}

/// Represents a complete order in the system
class Order {
  final String id;                // Unique identifier
  final String orderNumber;       // Human-readable order number
  final OrderType type;           // Type of order (ecommerce/store)
  final OrderStatus status;       // Current status
  final List<OrderItem> items;    // List of items in the order
  final double totalAmount;       // Total order amount
  final String? notes;            // Additional notes
  final Timestamp createdAt;      // When the order was created
  final Timestamp? updatedAt;     // When the order was last updated
  final String? paymentMethod;    // How the order was paid for
  final String? paymentStatus;    // Status of the payment

  // Ecommerce specific fields
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? shippingAddress;

  // Store specific fields
  final String? storeName;
  final String? storeLocation;
  final String? storeReference;

  final String? pickerId;     // New field
  final String? pickerName;   // New field
  final String? pickerSurname; // New field

  Order({
    required this.id,
    required this.orderNumber,
    required this.type,
    required this.status,
    required this.items,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.paymentMethod,
    this.paymentStatus,
    // Ecommerce fields
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.shippingAddress,
    // Store fields
    this.storeName,
    this.storeLocation,
    this.storeReference,
    this.pickerId,
    this.pickerName,
    this.pickerSurname,
  });

  /// Creates an Order from a Firestore document
  factory Order.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      
      // Parse items
      final List<OrderItem> orderItems = [];
      try {
        final itemsList = data['items'] as List<dynamic>?;
        if (itemsList != null) {
          orderItems.addAll(itemsList.map((item) {
            if (item is! Map<String, dynamic>) {
              throw FormatException('Invalid item format: $item');
            }
            return OrderItem.fromMap(item);
          }));
        }
      } catch (e) {
        debugPrint('Error parsing items: $e');
      }

      // Parse timestamps
      final createdAt = data['createdAt'] as Timestamp? ?? Timestamp.now();
      final updatedAt = data['updatedAt'] as Timestamp?;

      // Calculate total amount from items if not provided
      double totalAmount = 0.0;
      try {
        totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 
                     orderItems.fold(0.0, (sum, item) => sum + item.quantity);
      } catch (e) {
        debugPrint('Error calculating total amount: $e');
      }

      return Order(
        id: doc.id,
        orderNumber: data['orderNumber']?.toString() ?? '',
        type: OrderType.values.firstWhere(
          (e) => e.toString().split('.').last == (data['type']?.toString() ?? 'store'),
          orElse: () => OrderType.store,
        ),
        status: OrderStatus.values.firstWhere(
          (e) => e.toString().split('.').last == (data['status']?.toString() ?? 'pending'),
          orElse: () => OrderStatus.pending,
        ),
        items: orderItems,
        totalAmount: totalAmount,
        notes: data['notes']?.toString(),
        createdAt: createdAt,
        updatedAt: updatedAt,
        paymentMethod: data['paymentMethod']?.toString(),
        paymentStatus: data['paymentStatus']?.toString(),
        // Ecommerce fields
        customerName: data['customerName']?.toString(),
        customerEmail: data['customerEmail']?.toString(),
        customerPhone: data['customerPhone']?.toString(),
        shippingAddress: data['shippingAddress']?.toString(),
        // Store fields
        storeName: data['storeName']?.toString(),
        storeLocation: data['storeLocation']?.toString(),
        storeReference: data['storeReference']?.toString(),
        pickerId: data['pickerId']?.toString(),
        pickerName: data['pickerName']?.toString(),
        pickerSurname: data['pickerSurname']?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating Order from Firestore: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Converts the Order to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'orderNumber': orderNumber,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      // Ecommerce fields
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'shippingAddress': shippingAddress,
      // Store fields
      'storeName': storeName,
      'storeLocation': storeLocation,
      'storeReference': storeReference,
      'pickerId': pickerId,
      'pickerName': pickerName,
      'pickerSurname': pickerSurname,
    };
  }

  /// Creates a copy of this Order with the given fields replaced
  Order copyWith({
    String? id,
    String? orderNumber,
    OrderType? type,
    OrderStatus? status,
    List<OrderItem>? items,
    double? totalAmount,
    String? notes,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? paymentMethod,
    String? paymentStatus,
    // Ecommerce fields
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? shippingAddress,
    // Store fields
    String? storeName,
    String? storeLocation,
    String? storeReference,
    String? pickerId,
    String? pickerName,
    String? pickerSurname,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      // Ecommerce fields
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      // Store fields
      storeName: storeName ?? this.storeName,
      storeLocation: storeLocation ?? this.storeLocation,
      storeReference: storeReference ?? this.storeReference,
      pickerId: pickerId ?? this.pickerId,
      pickerName: pickerName ?? this.pickerName,
      pickerSurname: pickerSurname ?? this.pickerSurname,
    );
  }

  /// Helper getters
  bool get isEcommerce => type == OrderType.ecommerce;
  bool get isStore => type == OrderType.store;
  bool get isPending => status == OrderStatus.pending;
  bool get isProcessing => status == OrderStatus.processing;
  bool get isReady => status == OrderStatus.ready;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;

  /// Returns the total number of items in the order
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Returns true if the order has all required fields for its type
  bool get isValid {
    if (orderNumber.isEmpty) return false;
    if (items.isEmpty) return false;
    
    if (isEcommerce) {
      if (customerName?.isEmpty ?? true) return false;
      if (customerEmail?.isEmpty ?? true) return false;
      if (shippingAddress?.isEmpty ?? true) return false;
    }
    
    if (isStore) {
      if (storeName?.isEmpty ?? true) return false;
      if (storeLocation?.isEmpty ?? true) return false;
    }
    
    return true;
  }

  String? get pickerFullName => 
      pickerName != null && pickerSurname != null 
          ? '$pickerName $pickerSurname' 
          : null;
} 
