import 'package:equatable/equatable.dart';

/// Represents a settlement between two people
/// Example: "Alice owes Bob ₹50"
class Settlement extends Equatable {
  final String fromUserId; // Person who owes
  final String toUserId;   // Person who is owed
  final double amount;     // Amount owed

  const Settlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  @override
  List<Object?> get props => [fromUserId, toUserId, amount];
}

/// Greedy algorithm to calculate minimum number of settlements
/// Takes group balances map and returns a list of Settlement objects
/// 
/// Example:
/// Input: { "alice": 50, "bob": -30, "charlie": -20 }
/// Output: [
///   Settlement(fromUserId: "bob", toUserId: "alice", amount: 30),
///   Settlement(fromUserId: "charlie", toUserId: "alice", amount: 20)
/// ]
class DebtCalculator {
  /// Calculate settlements from a map of user balances
  /// Positive balance = person is owed money
  /// Negative balance = person owes money
  static List<Settlement> calculateSettlements(Map<String, double> balances) {
    final settlements = <Settlement>[];
    
    // Create copies to avoid modifying original
    final balancesCopy = Map<String, double>.from(balances);
    
    while (true) {
      // Find person with highest positive balance (most owed)
      String? maxDebtorId;
      double maxDebtorAmount = 0;
      
      for (final entry in balancesCopy.entries) {
        if (entry.value > maxDebtorAmount) {
          maxDebtorAmount = entry.value;
          maxDebtorId = entry.key;
        }
      }
      
      // Find person with lowest negative balance (owes most)
      String? maxCreditorId;
      double maxCreditorAmount = 0;
      
      for (final entry in balancesCopy.entries) {
        if (entry.value < 0 && entry.value.abs() > maxCreditorAmount) {
          maxCreditorAmount = entry.value.abs();
          maxCreditorId = entry.key;
        }
      }
      
      // If no more debts, we're done
      if (maxDebtorId == null || maxCreditorId == null) {
        break;
      }
      
      // Calculate settlement amount (minimum of the two)
      final settleAmount = _min(maxDebtorAmount, maxCreditorAmount);
      
      // Create settlement
      settlements.add(Settlement(
        fromUserId: maxCreditorId,
        toUserId: maxDebtorId,
        amount: settleAmount,
      ));
      
      // Update balances
      balancesCopy[maxDebtorId] = balancesCopy[maxDebtorId]! - settleAmount;
      balancesCopy[maxCreditorId] = balancesCopy[maxCreditorId]! + settleAmount;
      
      // Remove zero balances to clean up
      balancesCopy.removeWhere((_, value) => value.abs() < 0.01);
    }
    
    return settlements;
  }
  
  /// Helper to get minimum of two values
  static double _min(double a, double b) => a < b ? a : b;
  
  /// Format settlement for display
  static String formatSettlement(Settlement settlement, Map<String, String> userNames) {
    final fromName = userNames[settlement.fromUserId] ?? settlement.fromUserId;
    final toName = userNames[settlement.toUserId] ?? settlement.toUserId;
    final amount = settlement.amount.toStringAsFixed(2);
    return '$fromName owes $toName ₹$amount';
  }
  
  /// Get WhatsApp message format for a settlement
  static String getWhatsAppMessage(
    Settlement settlement,
    Map<String, String> userNames,
    String groupName,
  ) {
    final fromName = userNames[settlement.fromUserId] ?? settlement.fromUserId;
    final toName = userNames[settlement.toUserId] ?? settlement.toUserId;
    final amount = settlement.amount.toStringAsFixed(2);
    return '$fromName owes $toName ₹$amount in $groupName';
  }
}
