import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../widgets/charts/custom_bar_chart.dart';

class DatabaseService extends ChangeNotifier {
  static const String _storageKey = 'expense_tracker_records_v1';
  List<Expense> _expenses = [];

  List<Expense> get expenses => List.unmodifiable(_expenses);

  /// Initialize and load saved expenses from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _expenses = list.map((item) => Expense.fromJson(item as Map<String, dynamic>)).toList();
        // Sort newest first
        _expenses.sort((a, b) => b.date.compareTo(a.date));
      } catch (e) {
        debugPrint('Error parsing stored expenses: $e');
        _loadSeedData();
      }
    } else {
      // First time launch: load sample data for rich UI demonstration
      _loadSeedData();
      await _saveToDisk();
    }
    notifyListeners();
  }

  void _loadSeedData() {
    final now = DateTime.now();
    _expenses = [
      Expense(
        id: 'seed-1',
        title: 'Highlands Coffee',
        amount: 119900,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(hours: 3)),
        merchant: 'Highlands Coffee',
        note: 'Cà phê & Bánh mì sáng',
        isOcrScanned: true,
      ),
      Expense(
        id: 'seed-2',
        title: 'WinMart+ Mua sắm',
        amount: 173000,
        category: ExpenseCategory.shopping,
        date: now.subtract(const Duration(days: 1, hours: 2)),
        merchant: 'WinMart+',
        note: 'Sữa tươi, bánh mì, trái cây',
        isOcrScanned: true,
      ),
      Expense(
        id: 'seed-3',
        title: 'Đổ xăng xe máy',
        amount: 80000,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 2)),
        merchant: 'Petrolimex',
        note: 'Đổ đầy bình xăng Ron 95',
        isOcrScanned: false,
      ),
      Expense(
        id: 'seed-4',
        title: 'Circle K Ăn vặt',
        amount: 40000,
        category: ExpenseCategory.shopping,
        date: now.subtract(const Duration(days: 3)),
        merchant: 'Circle K',
        note: 'Mì trộn & nước tăng lực',
        isOcrScanned: true,
      ),
      Expense(
        id: 'seed-5',
        title: 'Hóa đơn Internet FPT',
        amount: 220000,
        category: ExpenseCategory.bills,
        date: now.subtract(const Duration(days: 5)),
        merchant: 'FPT Telecom',
        note: 'Cước internet cáp quang tháng',
        isOcrScanned: false,
      ),
      Expense(
        id: 'seed-6',
        title: 'Vé xem phim CGV',
        amount: 190000,
        category: ExpenseCategory.entertainment,
        date: now.subtract(const Duration(days: 6)),
        merchant: 'CGV Cinemas',
        note: 'Vé xem phim cuối tuần',
        isOcrScanned: false,
      ),
    ];
    _expenses.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _expenses.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
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
    _expenses.removeWhere((e) => e.id == id);
    await _saveToDisk();
    notifyListeners();
  }

  /// Total spending across all records
  double get totalSpending => _expenses.fold(0.0, (sum, item) => sum + item.amount);

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
          .where((e) => e.date.isAfter(day.subtract(const Duration(seconds: 1))) && e.date.isBefore(nextDay))
          .fold(0.0, (sum, e) => sum + e.amount);

      final label = (i == 0) ? 'Hôm nay' : dayLabels[day.weekday - 1];

      list.add(BarData(
        label: label,
        value: dayTotal,
        date: day,
      ));
    }

    return list;
  }
}
