import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/picker.dart';
import 'item_providers.dart';

final pickersProvider = StreamProvider<List<Picker>>((ref) {
  return ref.read(firestoreServiceProvider).getPickers();
});

// Selected picker provider for use during picking
final selectedPickerProvider = StateProvider<Picker?>((ref) => null); 