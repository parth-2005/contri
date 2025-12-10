import 'package:equatable/equatable.dart';

/// Domain Entity for Group
class Group extends Equatable {
  final String id;
  final String name;
  final List<String> members; // List of User IDs
  final Map<String, double> balances; // {userId: balance}
  final DateTime? createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.members,
    required this.balances,
    this.createdAt,
  });

  /// Get balance for a specific user
  double getBalanceForUser(String userId) {
    return balances[userId] ?? 0.0;
  }

  @override
  List<Object?> get props => [id, name, members, balances, createdAt];
}
