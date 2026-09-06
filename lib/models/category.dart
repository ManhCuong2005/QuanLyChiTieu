import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final String englishName;
  final IconData icon;
  final Color color;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.englishName,
    required this.icon,
    required this.color,
  });

  // 5 core categories required by project specifications:
  // (Food, Study, Travel, Gear, Entertainment)
  static const ExpenseCategory food = ExpenseCategory(
    id: 'food',
    name: 'Ăn uống',
    englishName: 'Food',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFFF6B6B),
  );

  static const ExpenseCategory study = ExpenseCategory(
    id: 'study',
    name: 'Học tập',
    englishName: 'Study',
    icon: Icons.school_rounded,
    color: Color(0xFFF59E0B),
  );

  static const ExpenseCategory travel = ExpenseCategory(
    id: 'travel',
    name: 'Di chuyển',
    englishName: 'Travel',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF3B82F6),
  );

  static const ExpenseCategory gear = ExpenseCategory(
    id: 'gear',
    name: 'Thiết bị & Đồ dùng',
    englishName: 'Gear',
    icon: Icons.devices_rounded,
    color: Color(0xFF10B981),
  );

  static const ExpenseCategory entertainment = ExpenseCategory(
    id: 'entertainment',
    name: 'Giải trí',
    englishName: 'Entertainment',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF8B5CF6),
  );

  static const ExpenseCategory housing = ExpenseCategory(
    id: 'housing',
    name: 'Tiền trọ',
    englishName: 'Housing',
    icon: Icons.home_rounded,
    color: Color(0xFFEC4899),
  );

  static const ExpenseCategory utilities = ExpenseCategory(
    id: 'utilities',
    name: 'Điện & nước',
    englishName: 'Utilities',
    icon: Icons.bolt_rounded,
    color: Color(0xFF06B6D4),
  );

  static const ExpenseCategory other = ExpenseCategory(
    id: 'other',
    name: 'Chi nhỏ / Khác',
    englishName: 'Other',
    icon: Icons.category_rounded,
    color: Color(0xFF64748B),
  );

  static const List<ExpenseCategory> defaultCategories = [
    food,
    study,
    travel,
    gear,
    entertainment,
    housing,
    utilities,
    other,
  ];

  factory ExpenseCategory.custom({required String id, required String name}) {
    return ExpenseCategory(
      id: id,
      name: name,
      englishName: name,
      icon: Icons.label_rounded,
      color: const Color(0xFF14B8A6),
    );
  }

  static ExpenseCategory fromId(String id) {
    return defaultCategories.firstWhere(
      (cat) => cat.id.toLowerCase() == id.toLowerCase(),
      orElse: () {
        // Backwards compatibility mapping
        if (id == 'transport') return travel;
        if (id == 'education') return study;
        if (id == 'shopping' || id == 'bills') return gear;
        return other;
      },
    );
  }

  static ExpenseCategory fromName(String name) {
    return defaultCategories.firstWhere(
      (cat) =>
          cat.name.toLowerCase() == name.toLowerCase() ||
          cat.englishName.toLowerCase() == name.toLowerCase(),
      orElse: () => other,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'englishName': englishName,
  };

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? 'other';
    final known = defaultCategories.where((category) => category.id == id);
    if (known.isNotEmpty) return known.first;
    return ExpenseCategory.custom(
      id: id,
      name: json['name'] as String? ?? 'Danh mục riêng',
    );
  }

  @override
  bool operator ==(Object other) => other is ExpenseCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
