import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/database_service.dart';

class CategorySelector extends StatelessWidget {
  final DatabaseService databaseService;
  final ExpenseCategory selectedCategory;
  final ValueChanged<ExpenseCategory> onSelected;

  const CategorySelector({
    super.key,
    required this.databaseService,
    required this.selectedCategory,
    required this.onSelected,
  });

  Future<void> _createCategory(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Tạo danh mục riêng'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Tên danh mục',
                hintText: 'Ví dụ: Thú cưng, Thể thao...',
                border: OutlineInputBorder(),
              ),
              onSubmitted:
                  (value) => Navigator.pop(dialogContext, value.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Tạo'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    final category = await databaseService.createCustomCategory(name);
    onSelected(category);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: databaseService,
      builder:
          (context, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...databaseService.categories.map((category) {
                final selected = selectedCategory.id == category.id;
                return ChoiceChip(
                  avatar: Icon(
                    category.icon,
                    size: 16,
                    color: selected ? Colors.white : category.color,
                  ),
                  label: Text(category.name),
                  selected: selected,
                  selectedColor: category.color,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (value) {
                    if (value) onSelected(category);
                  },
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tạo danh mục'),
                onPressed: () => _createCategory(context),
              ),
            ],
          ),
    );
  }
}
