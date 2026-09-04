import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../widgets/charts/custom_bar_chart.dart';
import 'receipt_image_storage.dart';
import 'expense_store.dart';

class DatabaseService extends ChangeNotifier {
  final ExpenseStore _store = ExpenseStore();
  List<Expense> _expenses = [];

  List<Expense> get expenses => List.unmodifiable(_expenses);

  /// Initialize and load saved expenses from storage
  Future<void> init() async {
    try {
      _expenses = await _store.load();
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      _expenses = [];
    }
    notifyListeners();
  }

  Future<void> _saveToDisk() async {
    try {
      await _store.save(_expenses);
    } catch (e) {
      debugPrint('Error saving expenses to disk: $e');
    }
  }

  /// Add new expense
  Future<void> addExpense(Expense expense) async {
    _expenses.insert(0, expense);
    _expenses.sort((a, b) => b.date.compareTo(a.date));
    await _saveToDisk();
    notifyListeners();
  }

  /// Update existing expense
  Future<void> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      await _saveToDisk();
      notifyListeners();
    }
  }

  /// Delete expense
  Future<void> deleteExpense(String id) async {
    final index = _expenses.indexWhere((item) => item.id == id);
    final expense = index >= 0 ? _expenses[index] : null;
    _expenses.removeWhere((e) => e.id == id);
    await _saveToDisk();
    try {
      await deleteReceiptImage(expense?.receiptImagePath);
    } catch (e) {
      debugPrint('Error deleting cached receipt image: $e');
    }
    notifyListeners();
  }

  /// Total spending across all records
  double get totalSpending =>
      _expenses.fold(0.0, (sum, item) => sum + item.amount);

  /// Spending grouped by category
  Map<ExpenseCategory, double> get categoryBreakdown {
    final map = <ExpenseCategory, double>{};
    for (final exp in _expenses) {
      map[exp.category] = (map[exp.category] ?? 0.0) + exp.amount;
    }
    return map;
  }

  /// Spending for the last 7 days for AnimatedBarChart
  List<BarData> getLast7DaysData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<BarData> list = [];

    final dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));

      final dayTotal = _expenses
          .where(
            (e) =>
                e.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
                e.date.isBefore(nextDay),
          )
          .fold(0.0, (sum, e) => sum + e.amount);

      final label = (i == 0) ? 'Hôm nay' : dayLabels[day.weekday - 1];

      list.add(BarData(label: label, value: dayTotal, date: day));
    }

    return list;
  }
}
