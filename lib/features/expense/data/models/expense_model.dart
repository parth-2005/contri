import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/expense.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Data Model for Expense (Firestore)
/// 
/// Supports unified architecture:
/// - groupId can be null for personal expenses
/// - Maintains backward compatibility with existing data
class ExpenseModel {
  final String id;
  final String? groupId; // NOW NULLABLE
  final String description;
  final double amount;
  final String paidBy;
  final Map<String, double> split; // Renamed from splitMap
  final String? splitType;
  final Map<String, double>? familyShares;
  final DateTime date;
  final DateTime? createdAt;
  final String category;
  final String type;
  final String? attributedMemberId;
  final String? localAttachmentPath;
  final bool isDeleted;

  ExpenseModel({
    required this.id,
    this.groupId, // NOW NULLABLE
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.split,
    this.splitType,
    this.familyShares,
    required this.date,
    this.createdAt,
    required this.category,
    required this.type,
    this.attributedMemberId,
    this.localAttachmentPath,
    this.isDeleted = false,
  });

  /// Convert to Domain Entity
  Expense toEntity() {
    return Expense(
      id: id,
      groupId: groupId,
      description: description,
      amount: amount,
      paidBy: paidBy,
      split: split,
      splitType: splitType,
      familyShares: familyShares,
      date: date,
      createdAt: createdAt,
      category: category,
      type: type,
      attributedMemberId: attributedMemberId,
      localAttachmentPath: localAttachmentPath,
      isDeleted: isDeleted,
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
      split: expense.split,
      splitType: expense.splitType,
      familyShares: expense.familyShares,
      date: expense.date,
      createdAt: expense.createdAt,
      category: expense.category,
      type: expense.type,
      attributedMemberId: expense.attributedMemberId,
      localAttachmentPath: expense.localAttachmentPath,
      isDeleted: expense.isDeleted,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      // Only include groupId if it's not null (personal expenses omit this field)
      if (groupId != null) FirebaseConstants.expenseGroupIdField: groupId,
      FirebaseConstants.expenseDescriptionField: description,
      FirebaseConstants.expenseAmountField: amount,
      FirebaseConstants.expensePaidByField: paidBy,
      FirebaseConstants.expenseSplitMapField: split,
      if (splitType != null) FirebaseConstants.expenseSplitTypeField: splitType,
      if (familyShares != null) FirebaseConstants.expenseFamilySharesField: familyShares,
      FirebaseConstants.expenseDateField: Timestamp.fromDate(date),
      FirebaseConstants.expenseCreatedAtField: FieldValue.serverTimestamp(),
      FirebaseConstants.expenseCategoryField: category,
      FirebaseConstants.expenseTypeField: type,
      if (attributedMemberId != null) FirebaseConstants.expenseMemberIdField: attributedMemberId,
      if (localAttachmentPath != null) 'localAttachmentPath': localAttachmentPath,
      'isDeleted': isDeleted,
    };
  }

  /// Convert from Firestore DocumentSnapshot
  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      // groupId is now nullable - allows personal expenses
      groupId: data[FirebaseConstants.expenseGroupIdField] as String?,
      description: data[FirebaseConstants.expenseDescriptionField] as String,
      amount: (data[FirebaseConstants.expenseAmountField] as num).toDouble(),
      paidBy: data[FirebaseConstants.expensePaidByField] as String,
      split: Map<String, double>.from(
        (data[FirebaseConstants.expenseSplitMapField] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
      ),
      splitType: data[FirebaseConstants.expenseSplitTypeField] as String?,
      familyShares: data[FirebaseConstants.expenseFamilySharesField] != null
          ? Map<String, double>.from(
              (data[FirebaseConstants.expenseFamilySharesField] as Map<String, dynamic>)
                  .map((key, value) => MapEntry(key, (value as num).toDouble())),
            )
          : null,
      date: (data[FirebaseConstants.expenseDateField] as Timestamp).toDate(),
      createdAt: data[FirebaseConstants.expenseCreatedAtField] != null
          ? (data[FirebaseConstants.expenseCreatedAtField] as Timestamp).toDate()
          : null,
      category: data[FirebaseConstants.expenseCategoryField] as String? ?? 'Other',
      type: data[FirebaseConstants.expenseTypeField] as String? ?? 'group',
      attributedMemberId: data[FirebaseConstants.expenseMemberIdField] as String?,
      localAttachmentPath: data['localAttachmentPath'] as String?,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }
}
