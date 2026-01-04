import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Provider for ExpenseRepository
final expenseRepositoryProvider = Provider((ref) {
  return ExpenseRepositoryImpl();
});

/// Provider for filtered expenses stream
/// Usage: ref.watch(filteredExpensesProvider(FilterParams(...)))
final filteredExpensesProvider = StreamProvider.family<List<Expense>, FilterParams>((ref, params) {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getFilteredExpenses(
    startDate: params.startDate,
    endDate: params.endDate,
    category: params.category,
    memberId: params.memberId,
    type: params.type,
  );
});

/// Parameters for filtering expenses
class FilterParams {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? category;
  final String? memberId;
  final String? type;

  const FilterParams({
    this.startDate,
    this.endDate,
    this.category,
    this.memberId,
    this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterParams &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          category == other.category &&
          memberId == other.memberId &&
          type == other.type;

  @override
  int get hashCode =>
      startDate.hashCode ^
      endDate.hashCode ^
      category.hashCode ^
      memberId.hashCode ^
      type.hashCode;
}

/// Provider for personal overview data
/// Calculates total spent this month for personal expenses
/// AND calculates owed/owing from all group expenses (not personal)
final personalOverviewProvider = StreamProvider<PersonalOverview>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when<Stream<PersonalOverview>>(
    data: (user) {
      if (user == null) {
        return Stream.value(
          PersonalOverview(totalSpentThisMonth: 0, totalOwed: 0, totalOwing: 0),
        );
      }

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // ✅ FIX: Fetch ALL expenses (Personal + Group) involved with user
      final allExpensesStream = repository.getFilteredExpenses(
        startDate: startOfMonth,
        endDate: endOfMonth,
        memberId: user.id, // Uses the fixed repo logic to get everything
      );

      return allExpensesStream.map((expenses) {
        double totalSpent = 0;
        double totalOwed = 0;
        double totalOwing = 0;

        for (final expense in expenses) {
          // 1. Calculate Total Spent (My Consumption)
          if (expense.type == 'personal') {
            totalSpent += expense.amount;
          } else {
            // In a group, my "Expense" is strictly my share of the split
            totalSpent += expense.split[user.id] ?? 0.0;
          }

          // 2. Calculate Net Balance (What I Paid vs What I Consumed)
          // Only applies to group/family expenses
          if (expense.type != 'personal') {
            final myPayment = expense.paidBy == user.id ? expense.amount : 0.0;
            final myConsumption = expense.split[user.id] ?? 0.0;
            
            // Net = Paid - Consumed
            final net = myPayment - myConsumption;

            if (net > 0) {
              totalOwed += net; // I paid extra -> Others owe me
            } else {
              totalOwing += net.abs(); // I paid less -> I owe others
            }
          }
        }

        return PersonalOverview(
          totalSpentThisMonth: totalSpent,
          totalOwed: totalOwed,
          totalOwing: totalOwing,
        );
      });
    },
    loading: () => Stream.value(
      PersonalOverview(totalSpentThisMonth: 0, totalOwed: 0, totalOwing: 0),
    ),
    error: (error, stack) => Stream.value(
      PersonalOverview(totalSpentThisMonth: 0, totalOwed: 0, totalOwing: 0),
    ),
  );
});

/// Personal overview data model
class PersonalOverview {
  final double totalSpentThisMonth;
  final double totalOwed; // Amount others owe to you
  final double totalOwing; // Amount you owe to others

  PersonalOverview({
    required this.totalSpentThisMonth,
    required this.totalOwed,
    required this.totalOwing,
  });

  double get netBalance => totalOwed - totalOwing;
}
