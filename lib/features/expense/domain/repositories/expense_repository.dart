import '../entities/expense.dart';

/// Domain Repository Interface for Expense Operations
abstract class ExpenseRepository {
  /// Create a new expense and update group balances atomically
  /// This is the core split logic method - all calculations happen client-side
  Future<void> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> splitMap,
  });

  /// Fetch expenses for a specific group
  Stream<List<Expense>> getExpensesForGroup(String groupId);

  /// Delete an expense and revert group balances
  Future<void> deleteExpense(String expenseId);
}
