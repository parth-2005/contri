import '../../expense/domain/entities/expense.dart';

/// Data class to hold group analytics stats
class GroupStats {
  final double totalSpent;
  final Map<String, double> categoryBreakdown;
  final List<DailyTotal> spendingCurve;

  const GroupStats({
    required this.totalSpent,
    required this.categoryBreakdown,
    required this.spendingCurve,
  });
}

class DailyTotal {
  final DateTime date;
  final double total;

  const DailyTotal({required this.date, required this.total});
}

/// Service to calculate group-wide analytics stats
class GroupAnalyticsService {
  GroupStats calculateGroupStats(List<Expense> expenses) {
    // Filter out settlements
    final validExpenses = expenses.where((e) => e.category != 'Settlement').toList();
    
    final totalSpent = _calculateTotalSpent(validExpenses);
    final categoryBreakdown = _calculateCategoryBreakdown(validExpenses);
    final spendingCurve = _calculateSpendingCurve(validExpenses);

    return GroupStats(
      totalSpent: totalSpent,
      categoryBreakdown: categoryBreakdown,
      spendingCurve: spendingCurve,
    );
  }

  double _calculateTotalSpent(List<Expense> expenses) {
    return expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, double> _calculateCategoryBreakdown(List<Expense> expenses) {
    final Map<String, double> breakdown = {};
    for (final expense in expenses) {
      breakdown.update(expense.category, (value) => value + expense.amount,
          ifAbsent: () => expense.amount);
    }
    return breakdown;
  }

  List<DailyTotal> _calculateSpendingCurve(List<Expense> expenses) {
    final Map<DateTime, double> dailyTotals = {};
    for (final expense in expenses) {
      final day = DateTime(expense.date.year, expense.date.month, expense.date.day);
      dailyTotals.update(day, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }

    final entries = dailyTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries
      .map((e) => DailyTotal(date: e.key, total: e.value))
      .toList();
  }
}
