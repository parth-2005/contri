import 'package:equatable/equatable.dart';

/// Domain Entity for Expense
/// 
/// AI-Ready Unified Architecture:
/// - Single model for both Personal and Group expenses
/// - groupId == null → Personal Expense (paidBy = currentUser, split = {currentUser: 100%})
/// - groupId != null → Group Expense (paidBy can be any member, split validated)
/// - Strict validation ensures data consistency for AI analysis
class Expense extends Equatable {
  final String id;
  
  /// Group ID - THE DIFFERENTIATOR
  /// - null: Personal Expense (individual tracking)
  /// - non-null: Group Expense (shared with others)
  final String? groupId;
  
  final String description;
  final double amount;
  
  /// User ID who paid for this expense
  /// - For Personal: Must be currentUser
  /// - For Group: Can be any group member
  final String paidBy;
  
  /// Split Map: {userId: amountOwed}
  /// - For Personal: Must be {currentUser: totalAmount}
  /// - For Group: Must sum to totalAmount, validated against group members
  final Map<String, double> split;
  
  /// Split Type: How the expense was divided
  /// - 'equal': Split equally among participants
  /// - 'family': Split by family shares (adults vs children)
  /// - 'custom': Manually specified amounts
  /// - 'percentage': Split by percentages
  final String? splitType;
  
  /// Family Shares: {userId: shareCount} when splitType == 'family'
  /// Example: {parent1: 1.0, parent2: 1.0, child1: 0.5}
  final Map<String, double>? familyShares;
  
  final DateTime date;
  
  /// Category: For analytics and AI insights
  /// Examples: 'Grocery', 'Fuel', 'EMI', 'Entertainment', 'Healthcare'
  final String category;
  
  /// Type: Legacy field for backward compatibility
  /// - 'personal': Individual expense
  /// - 'family': Family group expense
  /// - 'group': General group expense
  /// Note: Prefer using groupId == null check over this field
  final String type;
  
  /// Attributed Member: Which family member this expense belongs to
  /// Used for per-member spending analytics in family groups
  final String? attributedMemberId;

  const Expense({
    required this.id,
    this.groupId, // NOW NULLABLE
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.split, // Renamed from splitMap for clarity
    this.splitType,
    this.familyShares,
    required this.date,
    required this.category,
    required this.type,
    this.attributedMemberId,
  });
  
  /// Check if this is a personal expense
  bool get isPersonal => groupId == null;
  
  /// Check if this is a group expense
  bool get isGroup => groupId != null;
  
  /// Validate that split amounts sum to total amount
  bool get isSplitValid {
    final totalSplit = split.values.fold<double>(0.0, (sum, amount) => sum + amount);
    return (totalSplit - amount).abs() < 0.01; // Allow for floating point errors
  }
  
  /// Get the number of people this expense is split between
  int get splitCount => split.length;

  @override
  List<Object?> get props => [
        id,
        groupId, // Now nullable
        description,
        amount,
        paidBy,
        split,
        splitType,
        familyShares,
        date,
        category,
        type,
        attributedMemberId,
      ];
}
