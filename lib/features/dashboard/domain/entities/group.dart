import 'package:equatable/equatable.dart';

/// Domain Entity for Group
class Group extends Equatable {
  final String id;
  final String name;
  final List<String> members; // List of User IDs
  final Map<String, double> balances; // {userId: balance}
  final Map<String, double> defaultShares; // {userId: shareCount} for quick expense entry (e.g., 0.5 for child, 1 for adult)
  final DateTime? createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.members,
    required this.balances,
    this.defaultShares = const {},
    this.createdAt,
  });

  /// Get balance for a specific user
  double getBalanceForUser(String userId) {
    return balances[userId] ?? 0.0;
  }

  @override
  List<Object?> get props => [id, name, members, balances, defaultShares, createdAt];
}
