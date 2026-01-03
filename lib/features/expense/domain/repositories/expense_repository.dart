import '../entities/expense.dart';

/// Domain Repository Interface for Expense Operations
/// 
/// AI-Ready Architecture:
/// - Supports both personal (groupId == null) and group (groupId != null) expenses
/// - Validates data consistency for AI analysis
/// - Updates cached totalExpense for performance
abstract class ExpenseRepository {
  /// Create a new expense and update group balances atomically
  /// This is the core split logic method - all calculations happen client-side
  /// 
  /// If groupId is null: Creates a personal expense
  /// If groupId is not null: Creates a group expense with validation
  Future<void> createExpense({
    String? groupId, // NOW NULLABLE for personal expenses
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> split, // Renamed from splitMap
    String? splitType,
    Map<String, double>? familyShares,
    required String category,
    required String type,
    String? attributedMemberId,
  });

  /// Update an existing expense and recalculate group balances atomically
  Future<void> updateExpense({
    String? groupId, // NOW NULLABLE for personal expenses
    required String expenseId,
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> split, // Renamed from splitMap
    String? splitType,
    Map<String, double>? familyShares,
    required String category,
    required String type,
    String? attributedMemberId,
  });

  /// Fetch expenses for a specific group
  Stream<List<Expense>> getExpensesForGroup(String groupId);
  
  /// Fetch personal expenses for a specific user (groupId == null)
  Stream<List<Expense>> getPersonalExpenses(String userId);
  
  /// Fetch all expenses for a user (both personal and group)
  Stream<List<Expense>> getAllUserExpenses(String userId);

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
