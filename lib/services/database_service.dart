import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/personal_task.dart';
import '../widgets/charts/custom_bar_chart.dart';
import 'receipt_image_storage.dart';
import 'expense_store.dart';
import 'notification_service.dart';

class DatabaseService extends ChangeNotifier {
  final ExpenseStore _store = ExpenseStore();
  List<Expense> _expenses = [];
  List<ExpenseCategory> _customCategories = [];
  Map<String, double> _monthlyBudgets = {};
  List<Debt> _debts = [];
  static const _debtsStorageKey = 'expense_debts_v1';
  static const _personalTasksStorageKey = 'personal_tasks_v1';
  static const _qrImageStorageKey = 'personal_qr_image_v1';
  List<PersonalTask> _personalTasks = [];
  String? _qrImageBase64;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Debt> get debts => List.unmodifiable(_debts);
  List<PersonalTask> get personalTasks => List.unmodifiable(_personalTasks);
  String? get qrImageBase64 => _qrImageBase64;
  List<ExpenseCategory> get categories => List.unmodifiable([
    ...ExpenseCategory.defaultCategories,
    ..._customCategories,
  ]);

  /// Initialize and load saved expenses from storage
  Future<void> init() async {
    try {
      _expenses = await _store.load();
      final preferences = await SharedPreferences.getInstance();
      final savedCategories =
          preferences.getStringList('expense_custom_categories_v1') ?? [];
      _customCategories =
          savedCategories
              .map(
                (value) => ExpenseCategory.fromJson(
                  jsonDecode(value) as Map<String, dynamic>,
                ),
              )
              .toList();
      final savedBudgets = preferences.getString('expense_monthly_budgets_v1');
      if (savedBudgets != null && savedBudgets.isNotEmpty) {
        final values = jsonDecode(savedBudgets) as Map<String, dynamic>;
        _monthlyBudgets = values.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      }
      final savedDebts = preferences.getString(_debtsStorageKey);
      if (savedDebts != null && savedDebts.isNotEmpty) {
        _debts =
            (jsonDecode(savedDebts) as List<dynamic>)
                .map((item) => Debt.fromJson(item as Map<String, dynamic>))
                .where((item) => item.balance > 0)
                .toList();
      }
      final savedTasks = preferences.getString(_personalTasksStorageKey);
      if (savedTasks != null && savedTasks.isNotEmpty) {
        _personalTasks =
            (jsonDecode(savedTasks) as List<dynamic>)
                .map(
                  (item) => PersonalTask.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      }
      _qrImageBase64 = preferences.getString(_qrImageStorageKey);
      _debts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      _expenses = [];
    }
    notifyListeners();
  }

  Future<void> setQrImage(String imageBase64) async {
    _qrImageBase64 = imageBase64;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_qrImageStorageKey, imageBase64);
    notifyListeners();
  }

  Future<void> _savePersonalTasks() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _personalTasksStorageKey,
      jsonEncode(_personalTasks.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> addPersonalTask(PersonalTask task) async {
    _personalTasks.add(task);
    await _savePersonalTasks();
    await NotificationService.instance.scheduleTask(task);
    notifyListeners();
  }

  Future<void> updatePersonalTask(PersonalTask task) async {
    final index = _personalTasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    _personalTasks[index] = task;
    await _savePersonalTasks();
    await NotificationService.instance.scheduleTask(task);
    notifyListeners();
  }

  Future<void> deletePersonalTask(String id) async {
    _personalTasks.removeWhere((item) => item.id == id);
    await _savePersonalTasks();
    await NotificationService.instance.cancelTask(id);
    notifyListeners();
  }

  Future<void> movePersonalTaskToTop(String id) async {
    final index = _personalTasks.indexWhere((item) => item.id == id);
    if (index <= 0) return;
    final task = _personalTasks.removeAt(index);
    _personalTasks.insert(0, task);
    await _savePersonalTasks();
    notifyListeners();
  }

  Future<void> _saveDebts() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _debtsStorageKey,
      jsonEncode(_debts.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> addDebt(Debt debt) async {
    _debts.insert(0, debt);
    await _saveDebts();
    notifyListeners();
  }

  Future<void> adjustDebt(
    String id,
    double signedAmount, {
    String note = '',
  }) async {
    final index = _debts.indexWhere((item) => item.id == id);
    if (index < 0 || signedAmount == 0) return;
    final debt = _debts[index];
    final amount =
        signedAmount < 0
            ? -signedAmount.abs().clamp(0, debt.balance).toDouble()
            : signedAmount;
    final transaction = DebtTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      note: note,
      createdAt: DateTime.now(),
    );
    final updated = debt.copyWith(
      transactions: [...debt.transactions, transaction],
    );
    if (updated.balance <= 0) {
      _debts.removeAt(index);
    } else {
      _debts[index] = updated;
      _debts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    await _saveDebts();
    notifyListeners();
  }

  Future<void> settleDebt(String id) async {
    _debts.removeWhere((item) => item.id == id);
    await _saveDebts();
    notifyListeners();
  }

  Future<ExpenseCategory> createCustomCategory(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Tên danh mục không được trống');
    final existing = categories.where(
      (category) => category.name.toLowerCase() == cleanName.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;

    final category = ExpenseCategory.custom(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName,
    );
    _customCategories.add(category);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'expense_custom_categories_v1',
      _customCategories.map((item) => jsonEncode(item.toJson())).toList(),
    );
    notifyListeners();
    return category;
  }

  double budgetFor(String categoryId) => _monthlyBudgets[categoryId] ?? 0;

  Map<ExpenseCategory, double> get activeBudgets {
    return {
      for (final category in categories)
        if (budgetFor(category.id) > 0) category: budgetFor(category.id),
    };
  }

  double spentThisMonthFor(String categoryId, {DateTime? referenceDate}) {
    final reference = referenceDate ?? DateTime.now();
    return _expenses
        .where(
          (expense) =>
              expense.category.id == categoryId &&
              expense.date.year == reference.year &&
              expense.date.month == reference.month,
        )
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double remainingBudgetFor(String categoryId) {
    return budgetFor(categoryId) - spentThisMonthFor(categoryId);
  }

  Future<void> setMonthlyBudget(String categoryId, double amount) async {
    if (amount > 0) {
      _monthlyBudgets[categoryId] = amount;
    } else {
      _monthlyBudgets.remove(categoryId);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'expense_monthly_budgets_v1',
      jsonEncode(_monthlyBudgets),
    );
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
