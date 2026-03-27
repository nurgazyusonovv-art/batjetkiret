import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;

  Category({required this.id, required this.name, required this.icon});
}

// Available categories
final List<Category> categories = [
  Category(id: 'intercity', name: 'Шаарлар аралык', icon: Icons.directions_bus),
  Category(id: 'taxi', name: 'Такси', icon: Icons.local_taxi),
  Category(id: 'food', name: 'Тамак-аш', icon: Icons.restaurant),
  Category(id: 'groceries', name: 'Азык-түлүк', icon: Icons.shopping_cart),
  Category(id: 'pharmacy', name: 'Дарыкана', icon: Icons.local_pharmacy),
  Category(id: 'clothes', name: 'Кийим-кече', icon: Icons.checkroom),
  Category(id: 'electronics', name: 'Электроника', icon: Icons.phone_android),
  Category(id: 'flowers', name: 'Гүлдөр', icon: Icons.local_florist),
  Category(id: 'documents', name: 'Документтер', icon: Icons.description),
  Category(id: 'other', name: 'Башка', icon: Icons.category),
];
