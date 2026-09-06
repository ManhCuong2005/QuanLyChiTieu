import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../widgets/category_selector.dart';

class AddExpenseScreen extends StatefulWidget {
  final DatabaseService databaseService;
  final Expense? initialExpense;

  const AddExpenseScreen({
    super.key,
    required this.databaseService,
    this.initialExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  late ExpenseCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    final item = widget.initialExpense;
    _titleController = TextEditingController(text: item?.title ?? '');
    _amountController = TextEditingController(
      text: item != null ? item.amount.toStringAsFixed(0) : '',
    );
    _merchantController = TextEditingController(text: item?.merchant ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');

    _selectedDate = item?.date ?? DateTime.now();
    _selectedCategory = item?.category ?? ExpenseCategory.food;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }

    final enteredTitle = _titleController.text.trim();
    final expenseTitle =
        enteredTitle.isEmpty ? _selectedCategory.name : enteredTitle;

    if (widget.initialExpense != null) {
      final updated = widget.initialExpense!.copyWith(
        title: expenseTitle,
        amount: amount,
        category: _selectedCategory,
        date: _selectedDate,
        merchant: _merchantController.text.trim(),
        note: _noteController.text.trim(),
      );
      widget.databaseService.updateExpense(updated);
    } else {
      final newExpense = Expense(
        id: const Uuid().v4(),
        title: expenseTitle,
        amount: amount,
        category: _selectedCategory,
        date: _selectedDate,
        merchant: _merchantController.text.trim(),
        note: _noteController.text.trim(),
        isOcrScanned: false,
      );
      widget.databaseService.addExpense(newExpense);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.initialExpense != null
              ? 'Đã cập nhật khoản chi tiêu!'
              : 'Đã thêm chi tiêu thành công!',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final isEditing = widget.initialExpense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh Sửa Chi Tiêu' : 'Thêm Chi Tiêu Mới'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  labelText: 'Số tiền (VNĐ) *',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  suffixText: 'VNĐ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập số tiền';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tên khoản chi tiêu (không bắt buộc)',
                  hintText: 'Để trống sẽ dùng tên danh mục',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _merchantController,
                decoration: InputDecoration(
                  labelText: 'Nơi mua / Tên cửa hàng',
                  prefixIcon: const Icon(Icons.storefront_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Thời gian chi tiêu',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    dateFormatter.format(_selectedDate),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Danh mục chi tiêu:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              CategorySelector(
                databaseService: widget.databaseService,
                selectedCategory: _selectedCategory,
                onSelected: (category) {
                  setState(() => _selectedCategory = category);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Ghi chú thêm',
                  prefixIcon: const Icon(Icons.description_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveExpense,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    isEditing ? 'LƯU THAY ĐỔI' : 'THÊM KHOẢN CHI',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
