import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../widgets/expense_card.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  final DatabaseService databaseService;

  const ExpenseListScreen({super.key, required this.databaseService});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  String _searchQuery = '';
  String _selectedCategoryId = 'all';

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );
    final allExpenses = widget.databaseService.expenses;

    final filtered =
        allExpenses.where((expense) {
          final matchesSearch =
              expense.title.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              expense.merchant.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              expense.note.toLowerCase().contains(_searchQuery.toLowerCase());

          final matchesCategory =
              _selectedCategoryId == 'all' ||
              expense.category.id == _selectedCategoryId;

          return matchesSearch && matchesCategory;
        }).toList();

    final filteredTotal = filtered.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Sổ Giao Dịch Chi Tiêu')),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên, cửa hàng, ghi chú...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                        : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: _selectedCategoryId == 'all',
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategoryId = 'all';
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...widget.databaseService.categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        cat.icon,
                        size: 14,
                        color: isSelected ? Colors.white : cat.color,
                      ),
                      label: Text(cat.name),
                      selected: isSelected,
                      selectedColor: cat.color,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryId = selected ? cat.id : 'all';
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // Total bar for filtered view
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tìm thấy ${filtered.length} khoản chi',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  currencyFormatter.format(filteredTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child:
                filtered.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 54,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Không có giao dịch nào phù hợp',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final exp = filtered[index];
                        return ExpenseCard(
                          expense: exp,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => AddExpenseScreen(
                                      databaseService: widget.databaseService,
                                      initialExpense: exp,
                                    ),
                              ),
                            );
                          },
                          onDelete: () => _confirmDelete(exp),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Expense expense) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Xóa giao dịch này?'),
            content: Text(
              'Bạn có chắc muốn xóa "${expense.title}"? Thao tác này không thể hoàn tác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.databaseService.deleteExpense(expense.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa giao dịch')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
  }
}
