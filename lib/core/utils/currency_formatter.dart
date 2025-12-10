import 'package:intl/intl.dart';

/// Currency Formatter for Indian Rupee
class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(double amount) {
    return _formatter.format(amount);
  }

  /// Format without decimal places for whole numbers
  static String formatCompact(double amount) {
    if (amount % 1 == 0) {
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      ).format(amount);
    }
    return _formatter.format(amount);
  }

  /// Format with explicit sign (+ or -)
  static String formatWithSign(double amount) {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${format(amount)}';
  }
}
