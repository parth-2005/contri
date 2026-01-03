import 'package:equatable/equatable.dart';

/// Domain Entity for Expense
class Expense extends Equatable {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy; // User ID
  final Map<String, double> splitMap; // {userId: amountOwed}
  final String? splitType; // 'equal' | 'family' | 'custom'
  final Map<String, double>? familyShares; // {userId: shareCount} when splitType == 'family'
  final DateTime date;
  final String category; // Category like Grocery, Fuel, EMI, etc.
  final String type; // 'personal', 'family', or 'group'
  final String? attributedMemberId; // For tracking which family member this expense belongs to

  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splitMap,
    this.splitType,
    this.familyShares,
    required this.date,
    required this.category,
    required this.type,
    this.attributedMemberId,
  });

  @override
  List<Object?> get props => [
        id,
        groupId,
        description,
        amount,
        paidBy,
        splitMap,
        splitType,
        familyShares,
        date,
        category,
        type,
        attributedMemberId,
      ];
}
