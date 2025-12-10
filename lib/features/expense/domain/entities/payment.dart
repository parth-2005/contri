import 'package:equatable/equatable.dart';

/// Payment entity for tracking settlement payments
/// Records partial payments towards settlements
class Payment extends Equatable {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime date;

  const Payment({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.date,
  });

  @override
  List<Object?> get props => [id, groupId, fromUserId, toUserId, amount, date];
}
