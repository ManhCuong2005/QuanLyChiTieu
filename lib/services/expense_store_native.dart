import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class ExpenseStore {
  static const _legacyStorageKey = 'expense_tracker_records_v1';
  static const _table = 'expenses';
  Database? _database;

  bool get _supportsSqflite =>
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<List<Expense>> load() async {
    if (!_supportsSqflite) return _loadLegacyPreferences();

    final database = await _openDatabase();
    final rows = await database.query(_table, orderBy: 'created_at DESC');
    if (rows.isNotEmpty) {
      return rows
          .map(
            (row) => Expense.fromJson(
              jsonDecode(row['payload']! as String) as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    final legacyExpenses = await _loadLegacyPreferences();
    if (legacyExpenses.isNotEmpty) await save(legacyExpenses);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyStorageKey);
    return legacyExpenses;
  }

  Future<void> save(List<Expense> expenses) async {
    if (!_supportsSqflite) {
      await _saveLegacyPreferences(expenses);
      return;
    }

    final database = await _openDatabase();
    await database.transaction((transaction) async {
      await transaction.delete(_table);
      final batch = transaction.batch();
      for (final expense in expenses) {
        batch.insert(_table, {
          'id': expense.id,
          'created_at': expense.createdAt.toIso8601String(),
          'payload': jsonEncode(expense.toJson()),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Database> _openDatabase() async {
    final existing = _database;
    if (existing != null) return existing;

    _database = await openDatabase(
      'expense_tracker.db',
      version: 1,
      onCreate:
          (database, version) => database.execute('''
        CREATE TABLE $_table (
          id TEXT PRIMARY KEY,
          created_at TEXT NOT NULL,
          payload TEXT NOT NULL
        )
      '''),
    );
    return _database!;
  }

  Future<List<Expense>> _loadLegacyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_legacyStorageKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final values = jsonDecode(jsonString) as List<dynamic>;
    return values
        .map((value) => Expense.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveLegacyPreferences(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final values = expenses.map((expense) => expense.toJson()).toList();
    await prefs.setString(_legacyStorageKey, jsonEncode(values));
  }
}
