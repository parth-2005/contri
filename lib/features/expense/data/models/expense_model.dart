import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/expense.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Data Model for Expense (Firestore)
class ExpenseModel {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy;
  final Map<String, double> splitMap;
  final DateTime date;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.splitMap,
    required this.date,
  });

  /// Convert to Domain Entity
  Expense toEntity() {
    return Expense(
      id: id,
      groupId: groupId,
      description: description,
      amount: amount,
      paidBy: paidBy,
      splitMap: splitMap,
      date: date,
    );
  }

  /// Convert from Domain Entity
  factory ExpenseModel.fromEntity(Expense expense) {
    return ExpenseModel(
      id: expense.id,
      groupId: expense.groupId,
      description: expense.description,
      amount: expense.amount,
      paidBy: expense.paidBy,
      splitMap: expense.splitMap,
      date: expense.date,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.expenseGroupIdField: groupId,
      FirebaseConstants.expenseDescriptionField: description,
      FirebaseConstants.expenseAmountField: amount,
      FirebaseConstants.expensePaidByField: paidBy,
      FirebaseConstants.expenseSplitMapField: splitMap,
      FirebaseConstants.expenseDateField: Timestamp.fromDate(date),
      FirebaseConstants.expenseCreatedAtField: FieldValue.serverTimestamp(),
    };
  }

  /// Convert from Firestore DocumentSnapshot
  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      groupId: data[FirebaseConstants.expenseGroupIdField] as String,
      description: data[FirebaseConstants.expenseDescriptionField] as String,
      amount: (data[FirebaseConstants.expenseAmountField] as num).toDouble(),
      paidBy: data[FirebaseConstants.expensePaidByField] as String,
      splitMap: Map<String, double>.from(
        (data[FirebaseConstants.expenseSplitMapField] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
      ),
      date: (data[FirebaseConstants.expenseDateField] as Timestamp).toDate(),
    );
  }
}
