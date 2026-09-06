import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../services/database_service.dart';

class MonthlyBudgetSection extends StatelessWidget {
  final DatabaseService databaseService;

  const MonthlyBudgetSection({super.key, required this.databaseService});

  @override
  Widget build(BuildContext context) {
    final budgets = databaseService.activeBudgets;
    final month = DateFormat('MM/yyyy').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.savings_rounded,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ngân sách tháng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          month,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(budgets.isEmpty ? 'Thiết lập' : 'Chỉnh sửa'),
                  ),
                ],
              ),
              if (budgets.isEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Đặt hạn mức cho từng danh mục để theo dõi số tiền còn lại.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ...budgets.entries.map(
                  (entry) => _BudgetProgressRow(
                    category: entry.key,
                    budget: entry.value,
                    spent: databaseService.spentThisMonthFor(entry.key.id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BudgetEditorSheet(databaseService: databaseService),
    );
  }
}

class _BudgetProgressRow extends StatelessWidget {
  final ExpenseCategory category;
  final double budget;
  final double spent;

  const _BudgetProgressRow({
    required this.category,
    required this.budget,
    required this.spent,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compactCurrency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final remaining = budget - spent;
    final exceeded = remaining < 0;
    final progress = (spent / budget).clamp(0.0, 1.0);
    final statusColor = exceeded ? Colors.red : category.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                exceeded
                    ? 'Vượt ${formatter.format(-remaining)}'
                    : 'Còn ${formatter.format(remaining)}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: statusColor,
              backgroundColor: statusColor.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chi ${formatter.format(spent)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              Text(
                'Hạn mức ${formatter.format(budget)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetEditorSheet extends StatefulWidget {
  final DatabaseService databaseService;

  const _BudgetEditorSheet({required this.databaseService});

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  TextEditingController _controllerFor(ExpenseCategory category) {
    return _controllers.putIfAbsent(
      category.id,
      () => TextEditingController(
        text:
            widget.databaseService.budgetFor(category.id) > 0
                ? widget.databaseService
                    .budgetFor(category.id)
                    .toStringAsFixed(0)
                : '',
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _parseAmount(String input) {
    var value = input.toLowerCase().trim().replaceAll(' ', '');
    var multiplier = 1.0;
    if (value.endsWith('triệu')) {
      multiplier = 1000000;
      value = value.substring(0, value.length - 5);
    } else if (value.endsWith('tr')) {
      multiplier = 1000000;
      value = value.substring(0, value.length - 2);
    } else if (value.endsWith('k')) {
      multiplier = 1000;
      value = value.substring(0, value.length - 1);
    }
    value = value.replaceAll(',', '.');
    if (multiplier == 1) value = value.replaceAll('.', '');
    return (double.tryParse(value) ?? 0) * multiplier;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    for (final category in widget.databaseService.categories) {
      await widget.databaseService.setMonthlyBudget(
        category.id,
        _parseAmount(_controllerFor(category).text),
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã lưu ngân sách tháng.')));
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Tạo danh mục riêng'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Tên danh mục',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Tạo'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await widget.databaseService.createCustomCategory(name);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thiết lập ngân sách tháng',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Text(
            'Nhập 2tr, 500k hoặc số tiền đầy đủ. Để trống để bỏ hạn mức.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ...widget.databaseService.categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: _controllerFor(category),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: category.name,
                        prefixIcon: Icon(category.icon, color: category.color),
                        suffixText: 'VNĐ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _createCategory,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tạo danh mục riêng'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu ngân sách'),
            ),
          ),
        ],
      ),
    );
  }
}
