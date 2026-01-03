import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../models/expense_model.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Implementation of ExpenseRepository
/// Handles all client-side split logic to avoid Firebase Cloud Functions
/// 
/// AI-Ready Architecture:
/// - Validates personal vs group expense constraints
/// - Updates cached totalExpense for performance
/// - Maintains atomic batch operations for consistency
class ExpenseRepositoryImpl implements ExpenseRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  ExpenseRepositoryImpl({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  /// **CORE SPLIT LOGIC METHOD - AI-Ready**
  /// Creates expense and updates group balances atomically using Firestore batch
  /// All calculations happen on the client side (Zero Cloud Function cost)
  /// 
  /// Personal Expense (groupId == null):
  /// - Validates: paidBy == currentUser, split == {currentUser: amount}
  /// - No group balance updates
  /// 
  /// Group Expense (groupId != null):
  /// - Validates: paidBy in group.members, split sums to amount
  /// - Updates group balances and totalExpense
  @override
  Future<void> createExpense({
    String? groupId, // NOW NULLABLE for personal expenses
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> split, // Renamed from splitMap
    String? splitType,
    Map<String, double>? familyShares,
    required String category,
    required String type,
    String? attributedMemberId,
    DateTime? date,
  }) async {
    // **VALIDATION LOGIC**
    if (groupId == null) {
      // Personal Expense Validation
      _validatePersonalExpense(paidBy, split, amount);
    } else {
      // Group Expense Validation
      await _validateGroupExpense(groupId, paidBy, split, amount);
    }
    // **VALIDATION LOGIC**
    if (groupId == null) {
      // Personal Expense Validation
      _validatePersonalExpense(paidBy, split, amount);
    } else {
      // Group Expense Validation
      await _validateGroupExpense(groupId, paidBy, split, amount);
    }

    // Generate expense ID
    final expenseId = _uuid.v4();

    // Create Expense Model
    final expense = ExpenseModel(
      id: expenseId,
      groupId: groupId, // Can be null for personal expenses
      description: description,
      amount: amount,
      paidBy: paidBy,
      split: split, // Renamed from splitMap
      splitType: splitType,
      familyShares: familyShares,
      date: date ?? DateTime.now(),
      category: category,
      type: type,
      attributedMemberId: attributedMemberId,
    );

    // **CLIENT-SIDE SPLIT LOGIC CALCULATION**
    // Calculate net impact for each user:
    // - Payer gets credited: +amount
    // - Each person in split gets debited: -split[userId]
    final Map<String, double> balanceUpdates = {};

    // Step 1: Credit the payer
    balanceUpdates[paidBy] = amount;

    // Step 2: Debit each person in the split
    split.forEach((userId, owedAmount) {
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

    // 2. Update group balances and totalExpense ONLY for group expenses
    // Personal expenses (groupId == null) don't affect group balances
    if (groupId != null && type != 'personal') {
      final groupRef = _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId);

      // Update balances for each affected user
      balanceUpdates.forEach((userId, balanceChange) {
        // Use dot notation to update nested map field atomically
        batch.update(groupRef, {
          '${FirebaseConstants.groupBalancesField}.$userId':
              FieldValue.increment(balanceChange),
        });
      });
      
      // Update cached totalExpense in group document
      batch.update(groupRef, {
        FirebaseConstants.groupTotalExpenseField: FieldValue.increment(amount),
      });
    }

    // Commit the batch - all updates happen atomically
    await batch.commit();
  }

  /// **UPDATE EXPENSE METHOD - AI-Ready**
  /// Reverses old expense balance updates and applies new ones atomically
  @override
  Future<void> updateExpense({
    String? groupId, // NOW NULLABLE for personal expenses
    required String expenseId,
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> split, // Renamed from splitMap
    String? splitType,
    Map<String, double>? familyShares,
    required String category,
    required String type,
    String? attributedMemberId,
    DateTime? date,
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
    
    // **VALIDATION LOGIC**
    if (groupId == null) {
      // Personal Expense Validation
      _validatePersonalExpense(paidBy, split, amount);
    } else {
      // Group Expense Validation
      await _validateGroupExpense(groupId, paidBy, split, amount);
    }

    // Step 1: Calculate balance updates to REVERSE the old expense
    final Map<String, double> reverseUpdates = {};
    reverseUpdates[oldExpense.paidBy] = -oldExpense.amount;

    oldExpense.split.forEach((userId, owedAmount) {
      if (reverseUpdates.containsKey(userId)) {
        reverseUpdates[userId] = reverseUpdates[userId]! + owedAmount;
      } else {
        reverseUpdates[userId] = owedAmount;
      }
    });

    // Step 2: Calculate balance updates for NEW expense
    final Map<String, double> newUpdates = {};
    newUpdates[paidBy] = amount;

    split.forEach((userId, owedAmount) {
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
      split: split, // Renamed from splitMap
      splitType: splitType,
      familyShares: familyShares,
      date: date ?? oldExpense.date,
      category: category,
      type: type,
      attributedMemberId: attributedMemberId,
    );

    batch.update(oldExpenseDoc.reference, newExpense.toFirestore());

    // Update group balances and totalExpense ONLY for group expenses
    if (groupId != null && type != 'personal' && oldExpense.groupId != null && oldExpense.type != 'personal') {
      final groupRef = _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(groupId);

      // Apply balance changes
      finalUpdates.forEach((userId, balanceChange) {
        if (balanceChange != 0) {
          batch.update(groupRef, {
            '${FirebaseConstants.groupBalancesField}.$userId':
                FieldValue.increment(balanceChange),
          });
        }
      });
      
      // Update cached totalExpense: subtract old, add new
      final totalExpenseChange = amount - oldExpense.amount;
      if (totalExpenseChange != 0) {
        batch.update(groupRef, {
          FirebaseConstants.groupTotalExpenseField: FieldValue.increment(totalExpenseChange),
        });
      }
    }

    await batch.commit();
  }

  @override
  Stream<List<Expense>> getExpensesForGroup(String groupId) {
    return _firestore
        .collection(FirebaseConstants.expensesCollection)
        .where(FirebaseConstants.expenseGroupIdField, isEqualTo: groupId)
        .where('isDeleted', isEqualTo: false) // Filter out soft-deleted expenses
        .orderBy(FirebaseConstants.expenseDateField, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
            .toList());
  }

  /// Fetch filtered expenses across all contexts
  /// Uses Firestore queries for category and type to reduce data transfer
  /// Note: Composite indexes required in Firebase Console for complex queries
  @override
  Stream<List<Expense>> getFilteredExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? memberId,
    String? type,
  }) {
    // Build Firestore query with filters pushed to server
    Query query = _firestore
        .collection(FirebaseConstants.expensesCollection)
        .where('isDeleted', isEqualTo: false); // Always filter out soft-deleted expenses

    // Apply category filter at query level (Firestore does the work)
    if (category != null && category.isNotEmpty) {
      query = query.where(FirebaseConstants.expenseCategoryField, isEqualTo: category);
    }

    // Apply type filter at query level (Firestore does the work)
    if (type != null && type.isNotEmpty) {
      query = query.where(FirebaseConstants.expenseTypeField, isEqualTo: type);
    }

    // Apply date range filters if provided
    if (startDate != null) {
      query = query.where(
        FirebaseConstants.expenseDateField,
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        FirebaseConstants.expenseDateField,
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    // Order by date
    query = query.orderBy(FirebaseConstants.expenseDateField, descending: true);

    // Stream and apply in-memory filter only for member (complex logic)
    return query.snapshots().map((snapshot) {
      var expenses = snapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
          .toList();

      // Apply member filter (requires checking multiple fields)
      if (memberId != null && memberId.isNotEmpty) {
        expenses = expenses
            .where((e) => e.attributedMemberId == memberId || e.paidBy == memberId)
            .toList();
      }

      return expenses;
    });
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    // SOFT DELETE: Mark as deleted instead of removing (audit trail for financial data)
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

    expense.split.forEach((userId, owedAmount) {
      if (balanceUpdates.containsKey(userId)) {
        balanceUpdates[userId] = balanceUpdates[userId]! + owedAmount;
      } else {
        balanceUpdates[userId] = owedAmount;
      }
    });

    // Atomic batch to soft-delete expense and revert balances
    final batch = _firestore.batch();

    // 1. Soft delete expense (set isDeleted = true instead of hard delete)
    batch.update(expenseDoc.reference, {'isDeleted': true});

    // 2. Revert group balances and totalExpense ONLY for group expenses
    if (expense.groupId != null && expense.type != 'personal') {
      final groupRef = _firestore
          .collection(FirebaseConstants.groupsCollection)
          .doc(expense.groupId!);

      balanceUpdates.forEach((userId, balanceChange) {
        batch.update(groupRef, {
          '${FirebaseConstants.groupBalancesField}.$userId':
              FieldValue.increment(balanceChange),
        });
      });
      
      // Revert totalExpense
      batch.update(groupRef, {
        FirebaseConstants.groupTotalExpenseField: FieldValue.increment(-expense.amount),
      });
    }

    await batch.commit();
  }

  /// Record a payment - creates a reverse expense to reduce debt
  /// When user A pays user B some amount towards settlement,
  /// we create an expense where A paid B that amount
  /// 
  /// TRUST SCORE TRACKING: Silently calculates settlement time metrics
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
      split: {toUserId: amount}, // Renamed from splitMap
      date: now,
      category: 'Settlement',
      type: 'group',
    );

    // Calculate balance updates
    // Payer gets credited: +amount
    // Payee gets debited: -amount
    final Map<String, double> balanceUpdates = {
      fromUserId: amount,
      toUserId: -amount,
    };

    // **TRUST SCORE TRACKING: Calculate settlement time**
    await _updateTrustScoreForPayment(groupId, fromUserId, now);

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
  
  /// **SHADOW ANALYTICS: Update Trust Score for payment (not shown in UI)**
  /// Calculate settlement time and update rolling average
  Future<void> _updateTrustScoreForPayment(
    String groupId,
    String userId,
    DateTime paymentDate,
  ) async {
    try {
      // Find the most recent expense where this user owes money
      final recentExpensesSnapshot = await _firestore
          .collection(FirebaseConstants.expensesCollection)
          .where(FirebaseConstants.expenseGroupIdField, isEqualTo: groupId)
          .where('isDeleted', isEqualTo: false)
          .orderBy(FirebaseConstants.expenseDateField, descending: true)
          .limit(50)
          .get();
      
      // Find an expense where user is in split (owes money)
      Expense? relevantExpense;
      for (final doc in recentExpensesSnapshot.docs) {
        final expense = ExpenseModel.fromFirestore(doc).toEntity();
        if (expense.split.containsKey(userId) && expense.paidBy != userId) {
          relevantExpense = expense;
          break;
        }
      }
      
      if (relevantExpense == null) return; // No relevant expense found
      
      // Calculate settlement time in hours
      final settlementTime = paymentDate.difference(relevantExpense.date).inHours.toDouble();
      
      // Get or create member stats document
      final statsRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('memberStats')
          .doc(userId);
      
      final statsDoc = await statsRef.get();
      
      if (statsDoc.exists) {
        // Update existing stats with rolling average
        final data = statsDoc.data() as Map<String, dynamic>;
        final currentAvg = (data['avgSettlementTimeHours'] as num?)?.toDouble() ?? 0.0;
        final currentTotal = (data['totalSettlements'] as num?)?.toInt() ?? 0;
        
        // Calculate new rolling average
        final newAvg = ((currentAvg * currentTotal) + settlementTime) / (currentTotal + 1);
        
        await statsRef.update({
          'avgSettlementTimeHours': newAvg,
          'totalSettlements': currentTotal + 1,
          'lastSettlementDate': Timestamp.fromDate(paymentDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new stats document
        await statsRef.set({
          'userId': userId,
          'groupId': groupId,
          'avgSettlementTimeHours': settlementTime,
          'totalSettlements': 1,
          'lastSettlementDate': Timestamp.fromDate(paymentDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Silently fail - trust score is non-critical
      // Note: Trust score tracking is shadow analytics, failures are non-blocking
    }
  }
  
  /// **NEW METHOD: Get Personal Expenses**
  /// Fetch all personal expenses for a user (groupId == null)
  @override
  Stream<List<Expense>> getPersonalExpenses(String userId) {
    return _firestore
        .collection(FirebaseConstants.expensesCollection)
        .where(FirebaseConstants.expensePaidByField, isEqualTo: userId)
        .orderBy(FirebaseConstants.expenseDateField, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
            .where((expense) => expense.groupId == null) // Filter for personal
            .toList());
  }
  
  /// **NEW METHOD: Get All User Expenses**
  /// Fetch all expenses for a user (both personal and group)
  @override
  Stream<List<Expense>> getAllUserExpenses(String userId) {
    return _firestore
        .collection(FirebaseConstants.expensesCollection)
        .where(FirebaseConstants.expensePaidByField, isEqualTo: userId)
        .orderBy(FirebaseConstants.expenseDateField, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
            .toList());
  }
  
  // **VALIDATION METHODS**
  
  /// Validates personal expense constraints
  /// Rules:
  /// 1. Split must contain only the paidBy user
  /// 2. Split amount must equal total amount
  void _validatePersonalExpense(
    String paidBy,
    Map<String, double> split,
    double amount,
  ) {
    // Rule 1: Split must only contain paidBy user
    if (split.length != 1 || !split.containsKey(paidBy)) {
      throw Exception(
        'Personal expense must be split only with the payer. '
        'Expected: {$paidBy: $amount}, Got: $split'
      );
    }
    
    // Rule 2: Split amount must equal total
    final splitAmount = split[paidBy] ?? 0.0;
    if ((splitAmount - amount).abs() > 0.01) {
      throw Exception(
        'Personal expense split must equal total amount. '
        'Expected: $amount, Got: $splitAmount'
      );
    }
  }
  
  /// Validates group expense constraints
  /// Rules:
  /// 1. paidBy must be a group member
  /// 2. All split users must be group members
  /// 3. Split must sum to total amount
  Future<void> _validateGroupExpense(
    String groupId,
    String paidBy,
    Map<String, double> split,
    double amount,
  ) async {
    // Fetch group to validate members
    final groupDoc = await _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .get();
    
    if (!groupDoc.exists) {
      throw Exception('Group not found: $groupId');
    }
    
    final groupData = groupDoc.data() as Map<String, dynamic>;
    final members = List<String>.from(groupData[FirebaseConstants.groupMembersField] ?? []);
    
    // Rule 1: paidBy must be a group member
    if (!members.contains(paidBy)) {
      throw Exception(
        'Payer must be a group member. '
        'Group: $groupId, Payer: $paidBy, Members: $members'
      );
    }
    
    // Rule 2: All split users must be group members
    for (final userId in split.keys) {
      if (!members.contains(userId)) {
        throw Exception(
          'Split user must be a group member. '
          'Group: $groupId, User: $userId, Members: $members'
        );
      }
    }
    
    // Rule 3: Split must sum to total amount
    final splitTotal = split.values.fold<double>(0.0, (runningTotal, val) => runningTotal + val);
    if ((splitTotal - amount).abs() > 0.01) {
      throw Exception(
        'Split total must equal expense amount. '
        'Expected: $amount, Got: $splitTotal'
      );
    }
  }
}
