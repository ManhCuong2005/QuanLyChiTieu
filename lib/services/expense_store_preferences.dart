import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';

class ExpenseStore {
  static const _storageKey = 'expense_tracker_records_v1';

  Future<List<Expense>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    final values = jsonDecode(jsonString) as List<dynamic>;
    return values
        .map((value) => Expense.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final values = expenses.map((expense) => expense.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(values));
  }
}
