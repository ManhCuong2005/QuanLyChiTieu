import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const ExpenseCategory food = ExpenseCategory(
    id: 'food',
    name: 'Ăn uống',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFFF6B6B),
  );

  static const ExpenseCategory shopping = ExpenseCategory(
    id: 'shopping',
    name: 'Mua sắm',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFF4ECDC4),
  );

  static const ExpenseCategory transport = ExpenseCategory(
    id: 'transport',
    name: 'Di chuyển',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF45B7D1),
  );

  static const ExpenseCategory bills = ExpenseCategory(
    id: 'bills',
    name: 'Hóa đơn',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFFFA07A),
  );

  static const ExpenseCategory entertainment = ExpenseCategory(
    id: 'entertainment',
    name: 'Giải trí',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF9B59B6),
  );

  static const ExpenseCategory health = ExpenseCategory(
    id: 'health',
    name: 'Sức khỏe',
    icon: Icons.medical_services_rounded,
    color: Color(0xFF2ECC71),
  );

  static const ExpenseCategory education = ExpenseCategory(
    id: 'education',
    name: 'Học tập',
    icon: Icons.school_rounded,
    color: Color(0xFFF39C12),
  );

  static const ExpenseCategory other = ExpenseCategory(
    id: 'other',
    name: 'Khác',
    icon: Icons.category_rounded,
    color: Color(0xFF95A5A6),
  );

  static const List<ExpenseCategory> defaultCategories = [
    food,
    shopping,
    transport,
    bills,
    entertainment,
    health,
    education,
    other,
  ];

  static ExpenseCategory fromId(String id) {
    return defaultCategories.firstWhere(
      (cat) => cat.id.toLowerCase() == id.toLowerCase(),
      orElse: () => other,
    );
  }

  static ExpenseCategory fromName(String name) {
    return defaultCategories.firstWhere(
      (cat) => cat.name.toLowerCase() == name.toLowerCase(),
      orElse: () => other,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return fromId(json['id'] as String? ?? 'other');
  }
}
