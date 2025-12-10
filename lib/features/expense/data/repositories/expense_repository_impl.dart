import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_model.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Implementation of ExpenseRepository
/// Handles all client-side split logic to avoid Firebase Cloud Functions
class ExpenseRepositoryImpl implements ExpenseRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  ExpenseRepositoryImpl({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  /// **CORE SPLIT LOGIC METHOD**
  /// Creates expense and updates group balances atomically using Firestore batch
  /// All calculations happen on the client side (Zero Cloud Function cost)
  @override
  Future<void> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> splitMap,
  }) async {
    // Generate expense ID
    final expenseId = _uuid.v4();

    // Create Expense Model
    final expense = ExpenseModel(
      id: expenseId,
      groupId: groupId,
      description: description,
      amount: amount,
      paidBy: paidBy,
      splitMap: splitMap,
      date: DateTime.now(),
    );

    // **CLIENT-SIDE SPLIT LOGIC CALCULATION**
    // Calculate net impact for each user:
    // - Payer gets credited: +amount
    // - Each person in splitMap gets debited: -splitMap[userId]
    final Map<String, double> balanceUpdates = {};

    // Step 1: Credit the payer
    balanceUpdates[paidBy] = amount;

    // Step 2: Debit each person in the split
    splitMap.forEach((userId, owedAmount) {
      if (balanceUpdates.containsKey(userId)) {
        // If user is both payer and splitter (e.g., paying for themselves too)
        balanceUpdates[userId] = balanceUpdates[userId]! - owedAmount;
      } else {
        balanceUpdates[userId] = -owedAmount;
      }
    });

    // **ATOMIC FIRESTORE BATCH UPDATE**
    // Use batch to ensure all-or-nothing transaction
    final batch = _firestore.batch();

    // 1. Create the expense document
    final expenseRef = _firestore
        .collection(FirebaseConstants.expensesCollection)
        .doc(expenseId);
    batch.set(expenseRef, expense.toFirestore());

    // 2. Update group balances using FieldValue.increment (atomic operation)
    final groupRef = _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId);

    balanceUpdates.forEach((userId, balanceChange) {
      // Use dot notation to update nested map field atomically
      batch.update(groupRef, {
        '${FirebaseConstants.groupBalancesField}.$userId':
            FieldValue.increment(balanceChange),
      });
    });

    // Commit the batch - all updates happen atomically
    await batch.commit();
  }

  /// **UPDATE EXPENSE METHOD**
  /// Reverses old expense balance updates and applies new ones atomically
  @override
  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> splitMap,
  }) async {
    // Fetch the old expense to calculate reversal
    final oldExpenseDoc = await _firestore
        .collection(FirebaseConstants.expensesCollection)
        .doc(expenseId)
        .get();

    if (!oldExpenseDoc.exists) {
      throw Exception('Expense not found');
    }

    final oldExpense = ExpenseModel.fromFirestore(oldExpenseDoc);

    // Step 1: Calculate balance updates to REVERSE the old expense
    final Map<String, double> reverseUpdates = {};
    reverseUpdates[oldExpense.paidBy] = -oldExpense.amount;

    oldExpense.splitMap.forEach((userId, owedAmount) {
      if (reverseUpdates.containsKey(userId)) {
        reverseUpdates[userId] = reverseUpdates[userId]! + owedAmount;
      } else {
        reverseUpdates[userId] = owedAmount;
      }
    });

    // Step 2: Calculate balance updates for NEW expense
    final Map<String, double> newUpdates = {};
    newUpdates[paidBy] = amount;

    splitMap.forEach((userId, owedAmount) {
      if (newUpdates.containsKey(userId)) {
        newUpdates[userId] = newUpdates[userId]! - owedAmount;
      } else {
        newUpdates[userId] = -owedAmount;
      }
    });

    // Step 3: Combine reverse + new updates
    final Map<String, double> finalUpdates = {};
    
    // Add all users affected by either old or new expense
    final allUserIds = {...reverseUpdates.keys, ...newUpdates.keys};
    for (final userId in allUserIds) {
      final reversal = reverseUpdates[userId] ?? 0.0;
      final newChange = newUpdates[userId] ?? 0.0;
      finalUpdates[userId] = reversal + newChange;
    }

    // Step 4: Atomic batch update
    final batch = _firestore.batch();

    // Update the expense document
    final newExpense = ExpenseModel(
      id: expenseId,
      groupId: groupId,
      description: description,
      amount: amount,
      paidBy: paidBy,
      splitMap: splitMap,
      date: oldExpense.date,
    );

    batch.update(oldExpenseDoc.reference, newExpense.toFirestore());

    // Update group balances
    final groupRef = _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId);

    finalUpdates.forEach((userId, balanceChange) {
      if (balanceChange != 0) {
        batch.update(groupRef, {
          '${FirebaseConstants.groupBalancesField}.$userId':
              FieldValue.increment(balanceChange),
        });
      }
    });

    await batch.commit();
  }

  @override
  Stream<List<Expense>> getExpensesForGroup(String groupId) {
    return _firestore
        .collection(FirebaseConstants.expensesCollection)
        .where(FirebaseConstants.expenseGroupIdField, isEqualTo: groupId)
        .orderBy(FirebaseConstants.expenseDateField, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    // Fetch expense to calculate reversal
    final expenseDoc = await _firestore
        .collection(FirebaseConstants.expensesCollection)
        .doc(expenseId)
        .get();

    if (!expenseDoc.exists) {
      throw Exception('Expense not found');
    }

    final expense = ExpenseModel.fromFirestore(expenseDoc);

    // Calculate reverse balance updates (opposite of creation)
    final Map<String, double> balanceUpdates = {};
    balanceUpdates[expense.paidBy] = -expense.amount;

    expense.splitMap.forEach((userId, owedAmount) {
      if (balanceUpdates.containsKey(userId)) {
        balanceUpdates[userId] = balanceUpdates[userId]! + owedAmount;
      } else {
        balanceUpdates[userId] = owedAmount;
      }
    });

    // Atomic batch to delete expense and revert balances
    final batch = _firestore.batch();

    // 1. Delete expense
    batch.delete(expenseDoc.reference);

    // 2. Revert group balances
    final groupRef = _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(expense.groupId);

    balanceUpdates.forEach((userId, balanceChange) {
      batch.update(groupRef, {
        '${FirebaseConstants.groupBalancesField}.$userId':
            FieldValue.increment(balanceChange),
      });
    });

    await batch.commit();
  }

  /// Record a payment - creates a reverse expense to reduce debt
  /// When user A pays user B some amount towards settlement,
  /// we create an expense where A paid B that amount
  @override
  Future<void> recordPayment({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
  }) async {
    // Create a payment expense
    // fromUserId is the payer, toUserId is the payee
    // This effectively reduces the settlement between them
    
    final paymentId = _uuid.v4();
    final now = DateTime.now();

    // Create an expense with description noting it's a payment
    final payment = ExpenseModel(
      id: paymentId,
      groupId: groupId,
      description: 'Payment settlement',
      amount: amount,
      paidBy: fromUserId,
      splitMap: {toUserId: amount},
      date: now,
    );

    // Calculate balance updates
    // Payer gets credited: +amount
    // Payee gets debited: -amount
    final Map<String, double> balanceUpdates = {
      fromUserId: amount,
      toUserId: -amount,
    };

    // Atomic batch update
    final batch = _firestore.batch();

    // 1. Create the payment expense document
    final paymentRef = _firestore
        .collection(FirebaseConstants.expensesCollection)
        .doc(paymentId);
    batch.set(paymentRef, payment.toFirestore());

    // 2. Update group balances
    final groupRef = _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId);

    balanceUpdates.forEach((userId, balanceChange) {
      batch.update(groupRef, {
        '${FirebaseConstants.groupBalancesField}.$userId':
            FieldValue.increment(balanceChange),
      });
    });

    await batch.commit();
  }
}
