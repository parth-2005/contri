import 'package:equatable/equatable.dart';

/// Domain Entity for Expense
class Expense extends Equatable {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy; // User ID
  final Map<String, double> splitMap; // {userId: amountOwed}
  final DateTime date;

  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splitMap,
    required this.date,
  });

  @override
  List<Object?> get props => [
        id,
        groupId,
        description,
        amount,
        paidBy,
        splitMap,
        date,
      ];
}
