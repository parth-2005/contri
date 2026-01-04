/// Utility class for handling money calculations with proper precision
/// Prevents floating point errors and ensures all monetary values are rounded to 2 decimal places
/// 
/// **Audit 1: Money Precision**
/// This utility solves the "0.1 + 0.2 = 0.300000004" problem in financial calculations
class MoneyUtils {
  /// Round a double value to 2 decimal places (standard for currency)
  /// 
  /// Example:
  /// ```dart
  /// MoneyUtils.roundToTwo(0.1 + 0.2); // Returns 0.30 instead of 0.30000000000000004
  /// MoneyUtils.roundToTwo(100 / 3);   // Returns 33.33
  /// ```
  static double roundToTwo(double value) {
    if (!value.isFinite) return 0.0; // Protect against NaN and Infinity
    return double.parse(value.toStringAsFixed(2));
  }

  /// Distribute an amount equally among N people
  /// Handles the "extra penny" problem (e.g., 100 / 3 = 33.33 + 33.33 + 33.34)
  /// 
  /// Example:
  /// ```dart
  /// final splits = MoneyUtils.distributeEqually(100, 3);
  /// // Returns [33.33, 33.33, 33.34] - sum exactly equals 100
  /// ```
  static List<double> distributeEqually(double amount, int count) {
    if (count <= 0) return [];
    if (count == 1) return [roundToTwo(amount)];

    final baseAmount = roundToTwo(amount / count);
    final splits = List<double>.filled(count, baseAmount);
    
    // Calculate the sum to find the difference (extra pennies)
    final currentSum = baseAmount * count;
    final difference = roundToTwo(amount - currentSum);
    
    // Add the extra pennies to the last person (standard practice)
    splits[count - 1] = roundToTwo(splits[count - 1] + difference);
    
    return splits;
  }

  /// Distribute an amount proportionally based on shares
  /// Ensures the sum equals the original amount exactly
  /// 
  /// Example:
  /// ```dart
  /// final shares = {'adult1': 1.0, 'adult2': 1.0, 'child': 0.5};
  /// final splits = MoneyUtils.distributeByShares(100, shares);
  /// // Returns {'adult1': 40.00, 'adult2': 40.00, 'child': 20.00}
  /// ```
  static Map<String, double> distributeByShares(
    double amount,
    Map<String, double> shares,
  ) {
    final result = <String, double>{};
    
    if (shares.isEmpty) return result;
    
    final totalShares = shares.values.fold<double>(0.0, (sum, val) => sum + val);
    if (totalShares == 0) return result; // Division by zero protection

    // Calculate base splits
    double allocatedSum = 0.0;
    String? lastKey;
    
    for (final entry in shares.entries) {
      lastKey = entry.key;
      final split = roundToTwo((amount * entry.value) / totalShares);
      result[entry.key] = split;
      allocatedSum += split;
    }

    // Fix rounding errors by adjusting the last person's split
    if (lastKey != null) {
      final difference = roundToTwo(amount - allocatedSum);
      result[lastKey] = roundToTwo(result[lastKey]! + difference);
    }

    return result;
  }

  /// Safely add two monetary values with proper rounding
  static double add(double a, double b) {
    return roundToTwo(a + b);
  }

  /// Safely subtract two monetary values with proper rounding
  static double subtract(double a, double b) {
    return roundToTwo(a - b);
  }

  /// Check if two monetary values are equal (within 1 cent tolerance)
  /// Useful for validating splits
  static bool areEqual(double a, double b, {double tolerance = 0.01}) {
    return (a - b).abs() < tolerance;
  }

  /// Validate that a list of splits sums to the expected total
  /// Returns true if valid (within 1 cent tolerance)
  static bool validateSplitSum(List<double> splits, double expectedTotal) {
    final sum = splits.fold<double>(0.0, (sum, val) => sum + val);
    return areEqual(sum, expectedTotal);
  }

  /// Validate that a map of splits sums to the expected total
  /// Returns true if valid (within 1 cent tolerance)
  static bool validateSplitMapSum(
    Map<String, double> splits,
    double expectedTotal,
  ) {
    final sum = splits.values.fold<double>(0.0, (sum, val) => sum + val);
    return areEqual(sum, expectedTotal);
  }
}
