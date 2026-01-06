import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Provider for ExpenseRepository
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
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
      // Define the current month window
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // ✅ FIX 1: Fetch ALL expenses (Remove Date Filter)
      // Debt calculations must include history (e.g., Expense in Dec, Settlement in Jan)
      final allExpensesStream = repository.getFilteredExpenses(
        memberId: user.id,
      );

      return allExpensesStream.map((expenses) {
        double totalSpentThisMonth = 0;
        double globalNetBalance = 0;
        for (final expense in expenses) {
          // print ('Expense: ${expense.id}, Type: ${expense.type}, Amount: ${expense.amount}, Date: ${expense.date}, PaidBy: ${expense.paidBy}, Split: ${expense.split}');
          final isSettlement = expense.category == 'Settlement';
          
          // Check if this specific expense happened this month
          final isThisMonth = expense.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && 
                              expense.date.isBefore(endOfMonth.add(const Duration(seconds: 1)));

          // 1. Calculate Total Spent (My Consumption) - THIS MONTH ONLY
          if (!isSettlement && isThisMonth) {
            if (expense.type == 'personal') {
              totalSpentThisMonth += expense.amount;
            }
            else if (expense.type == 'group') {
              totalSpentThisMonth += expense.split[user.id] ?? 0.0;
            }
          }

          // 2. Calculate Net Balance - LIFETIME (All History)
          // We include ALL transactions to ensure debts cancel out correctly
          if (expense.type != 'personal') {
            final myPayment = expense.paidBy == user.id ? expense.amount : 0.0;
            final myConsumption = expense.split[user.id] ?? 0.0;
            
            // + Positive: I paid more than I consumed (I am owed)
            // - Negative: I consumed more than I paid (I owe)
            globalNetBalance += (myPayment - myConsumption);
          }
        }

        // 3. Final Result
        return PersonalOverview(
          totalSpentThisMonth: totalSpentThisMonth,
          totalOwed: globalNetBalance > 0.01 ? globalNetBalance : 0,
          totalOwing: globalNetBalance < -0.01 ? globalNetBalance.abs() : 0, // Threshold handles floating point errors
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
