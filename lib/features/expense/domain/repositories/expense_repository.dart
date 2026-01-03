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
    String? splitType,
    Map<String, double>? familyShares,
    required String category,
    required String type,
    String? attributedMemberId,
  });

  /// Update an existing expense and recalculate group balances atomically
  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> splitMap,
    String? splitType,
    Map<String, double>? familyShares,
    required String category,
    required String type,
    String? attributedMemberId,
  });

  /// Fetch expenses for a specific group
  Stream<List<Expense>> getExpensesForGroup(String groupId);

  /// Fetch filtered expenses across all contexts
  Stream<List<Expense>> getFilteredExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? memberId,
    String? type,
  });

  /// Delete an expense and revert group balances
  Future<void> deleteExpense(String expenseId);

  /// Record a payment for settlement
  /// This creates a reverse expense that reduces the debt
  Future<void> recordPayment({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
  });
}
