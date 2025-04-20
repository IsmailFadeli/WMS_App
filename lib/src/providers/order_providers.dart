import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../services/firestore_service.dart';
import 'firestore_providers.dart';

final orderProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getOrderStream(orderId);
}); 