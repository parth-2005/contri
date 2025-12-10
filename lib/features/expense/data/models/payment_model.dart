import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/payment.dart';

/// Firestore model for Payment
class PaymentModel extends Payment {
  const PaymentModel({
    required super.id,
    required super.groupId,
    required super.fromUserId,
    required super.toUserId,
    required super.amount,
    required super.date,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
    };
  }

  /// Create from Firestore document
  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: data['id'] ?? '',
      groupId: data['groupId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to entity
  Payment toEntity() => Payment(
    id: id,
    groupId: groupId,
    fromUserId: fromUserId,
    toUserId: toUserId,
    amount: amount,
    date: date,
  );
}
