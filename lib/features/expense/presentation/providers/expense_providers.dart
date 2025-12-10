import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository_impl.dart';

/// Provider for ExpenseRepository
final expenseRepositoryProvider = Provider((ref) {
  return ExpenseRepositoryImpl();
});
