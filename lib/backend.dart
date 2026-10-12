// backend.dart  (put in lib/backend.dart)
// Expense tracker backend: data model, local storage, budget and stats.
//
// pubspec.yaml needs:
//   shared_preferences: ^2.5.6
//   google_fonts: (added by `flutter pub add google_fonts`)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Change this one line to use another currency, e.g. 'GH₵', '€', '£'.
const String currencySymbol = '\$';

/// 1284.5 -> $1,284.50   (cents: false -> $1,285)
String formatMoney(double value, {bool cents = true}) {
  final fixed = value.abs().toStringAsFixed(cents ? 2 : 0);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  final sign = value < 0 ? '-' : '';
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '$sign$currencySymbol$whole$decimals';
}

enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  health,
  fun,
  other;

  String get label => switch (this) {
        ExpenseCategory.food => 'Food',
        ExpenseCategory.transport => 'Transport',
        ExpenseCategory.shopping => 'Shopping',
        ExpenseCategory.bills => 'Bills',
        ExpenseCategory.health => 'Health',
        ExpenseCategory.fun => 'Fun',
        ExpenseCategory.other => 'Other',
      };
}

/// One expense entry.
class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category.name,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => ExpenseCategory.other,
        ),
        date: DateTime.parse(json['date']),
      );
}

/// All data and logic. The UI listens to this class.
class ExpenseBackend extends ChangeNotifier {
  static const _expensesKey = 'expenses_v1';
  static const _budgetKey = 'monthly_budget_v1';

  final List<Expense> _expenses = []; // always newest first
  double _budget = 2000;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  // ---------- Basic getters ----------

  List<Expense> get expenses => List.unmodifiable(_expenses);
  double get budget => _budget;

  /// The month currently being viewed (day is always 1).
  DateTime get month => _month;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  bool get canGoNext {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  // ---------- Stats for the viewed month ----------

  List<Expense> get monthExpenses => _expenses
      .where((e) => e.date.year == _month.year && e.date.month == _month.month)
      .toList();

  double get monthTotal =>
      monthExpenses.fold<double>(0, (sum, e) => sum + e.amount);

  double get remaining => _budget - monthTotal;

  bool get isOverBudget => monthTotal > _budget;

  /// 0.0 (nothing left) to 1.0 (nothing spent).
  double get remainingFraction =>
      (remaining / _budget).clamp(0.0, 1.0).toDouble();

  /// Days left in the month, including today. 0 for past months.
  int get daysLeft {
    if (!isCurrentMonth) return 0;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return daysInMonth - now.day + 1;
  }

  /// How much you can spend per day for the rest of the month.
  double get dailyAllowance =>
      (daysLeft > 0 && remaining > 0) ? remaining / daysLeft : 0.0;

  /// Spending per category, biggest first.
  List<MapEntry<ExpenseCategory, double>> get categoryTotals {
    final map = <ExpenseCategory, double>{};
    for (final e in monthExpenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Total spent on each of the last 7 days (oldest first, today last).
  List<MapEntry<DateTime, double>> get last7Days {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day - (6 - i));
      final total = _expenses
          .where((e) => _sameDay(e.date, day))
          .fold<double>(0, (sum, e) => sum + e.amount);
      return MapEntry(day, total);
    });
  }

  /// The viewed month's expenses grouped by day, newest day first.
  Map<DateTime, List<Expense>> get groupedByDay {
    final map = <DateTime, List<Expense>>{};
    for (final e in monthExpenses) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }

  // ---------- Actions ----------

  /// Load saved data. Call once when the app starts.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _budget = prefs.getDouble(_budgetKey) ?? 2000;

    final saved = prefs.getString(_expensesKey);
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      _expenses
        ..clear()
        ..addAll(list.map((e) => Expense.fromJson(e)));
      _sort();
    }
    notifyListeners();
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
  }) async {
    _expenses.add(Expense(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      category: category,
      date: date,
    ));
    _sort();
    // Jump to the month the expense belongs to so it is visible.
    _month = DateTime(date.year, date.month);
    await _commit();
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await _commit();
  }

  /// Used by "Undo" after a delete.
  Future<void> restoreExpense(Expense expense) async {
    _expenses.add(expense);
    _sort();
    await _commit();
  }

  Future<void> setBudget(double amount) async {
    if (amount <= 0) return;
    _budget = amount;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, _budget);
  }

  void previousMonth() {
    _month = DateTime(_month.year, _month.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    if (!canGoNext) return;
    _month = DateTime(_month.year, _month.month + 1);
    notifyListeners();
  }

  // ---------- Helpers ----------

  void _sort() {
    _expenses.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  }

  /// Update the UI first, then save.
  Future<void> _commit() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _expensesKey,
      jsonEncode(_expenses.map((e) => e.toJson()).toList()),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}