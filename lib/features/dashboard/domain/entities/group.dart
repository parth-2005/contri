import 'package:equatable/equatable.dart';

/// Group Type Enum - Defines the purpose/context of the group
enum GroupType {
  trip,    // Travel/trip expenses
  home,    // Household/family expenses (persistent)
  couple,  // Couple-specific expenses
  other,   // General/miscellaneous
}

/// Extension for GroupType to convert to/from string
extension GroupTypeExtension on GroupType {
  String toShortString() {
    return toString().split('.').last;
  }

  static GroupType fromString(String value) {
    return GroupType.values.firstWhere(
      (e) => e.toShortString() == value,
      orElse: () => GroupType.other,
    );
  }
}

/// Domain Entity for Group
/// 
/// AI-Ready Architecture:
/// - Supports both temporary groups (trips) and persistent groups (family/home)
/// - Settings field allows feature toggles without schema changes
/// - totalExpense provides cached summary for efficient list displays
class Group extends Equatable {
  final String id;
  final String name;
  final List<String> members; // List of User IDs
  final Map<String, double> balances; // {userId: balance}
  final Map<String, double> defaultShares; // {userId: shareCount} for quick expense entry (e.g., 0.5 for child, 1 for adult)
  final DateTime? createdAt;
  
  /// Group Type - Defines the purpose/context of the group
  final GroupType type;
  
  /// Settings Map - Flexible configuration for feature toggles
  /// Examples:
  /// - 'showAnalytics': true/false
  /// - 'isPinned': true/false
  /// - 'allowPersonalExpenses': true/false
  /// - 'notifyOnNewExpense': true/false
  final Map<String, dynamic> settings;
  
  /// Total Expense - Cached sum of all expenses in this group
  /// Updated via batch writes when expenses are added/edited
  /// Enables efficient list displays without fetching all expenses
  final double totalExpense;

  const Group({
    required this.id,
    required this.name,
    required this.members,
    required this.balances,
    this.defaultShares = const {},
    this.createdAt,
    this.type = GroupType.other,
    this.settings = const {},
    this.totalExpense = 0.0,
  });

  /// Get balance for a specific user
  double getBalanceForUser(String userId) {
    return balances[userId] ?? 0.0;
  }
  
  /// Check if a specific setting is enabled
  bool isSettingEnabled(String key) {
    final value = settings[key];
    return value is bool ? value : false;
  }
  
  /// Get a setting value with type safety
  T? getSettingValue<T>(String key) {
    final value = settings[key];
    return value is T ? value : null;
  }
  
  /// Check if this is a persistent group (Family/Home type)
  bool get isPersistent => type == GroupType.home;
  
  /// Check if analytics should be shown for this group
  bool get showAnalytics => isSettingEnabled('showAnalytics');
  
  /// Check if this group is pinned in the UI
  bool get isPinned => isSettingEnabled('isPinned');

  @override
  List<Object?> get props => [
    id,
    name,
    members,
    balances,
    defaultShares,
    createdAt,
    type,
    settings,
    totalExpense,
  ];
}
