import 'package:cloud_firestore/cloud_firestore.dart';

class Picker {
  final String id;
  final String name;
  final String surname;
  
  Picker({
    required this.id,
    required this.name,
    required this.surname,
  });

  String get fullName => '$name $surname';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
    };
  }

  factory Picker.fromMap(Map<String, dynamic> map, String id) {
    return Picker(
      id: id,
      name: map['name'] ?? '',
      surname: map['surname'] ?? '',
    );
  }
} 