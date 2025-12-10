# Contri Pro - Edit Expense Implementation Guide

## 🎯 Overview

This guide provides step-by-step instructions for implementing the **Edit Expense Engine** (Upgrade #1), which enables users to modify existing expenses with automatic balance reversal and recalculation.

---

## 📋 Current AddExpenseScreen Status

### Current Constructor
```dart
class AddExpenseScreen extends ConsumerStatefulWidget {
  final Group group;
  const AddExpenseScreen({super.key, required this.group});
}
```

### Required Changes
Add optional parameter for editing:
```dart
class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;  // Change to groupId (more flexible)
  final Expense? expenseToEdit;  // NEW: For edit mode

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    this.expenseToEdit,
  });
}
```

---

## 🔧 Step 1: Update Domain Layer

### File: `lib/features/expense/domain/repositories/expense_repository.dart`

**Current:**
```dart
abstract class ExpenseRepository {
  Future<void> createExpense({...});
  Stream<List<Expense>> getExpensesForGroup(String groupId);
  Future<void> deleteExpense(String expenseId);
}
```

**Add Method:**
```dart
abstract class ExpenseRepository {
  Future<void> createExpense({...});
  
  // NEW METHOD
  Future<void> updateExpense({
    required String expenseId,
    required String groupId,
    required String description,
    required double amount,
    required String paidBy,
    required Map<String, double> splitMap,
    required Expense oldExpense,  // To reverse old balances
  });
  
  Stream<List<Expense>> getExpensesForGroup(String groupId);
  Future<void> deleteExpense(String expenseId);
}
```

---

## 🔧 Step 2: Update Data Layer

### File: `lib/features/expense/data/repositories/expense_repository_impl.dart`

**Add Implementation:**
```dart
@override
Future<void> updateExpense({
  required String expenseId,
  required String groupId,
  required String description,
  required double amount,
  required String paidBy,
  required Map<String, double> splitMap,
  required Expense oldExpense,
}) async {
  // Step 1: Calculate reversal updates (negative of old balances)
  final Map<String, double> reversalUpdates = {};
  
  // Reverse old payer credit
  reversalUpdates[oldExpense.paidBy] = -oldExpense.amount;
  
  // Reverse old split debits
  oldExpense.splitMap.forEach((userId, owedAmount) {
    if (reversalUpdates.containsKey(userId)) {
      reversalUpdates[userId] = reversalUpdates[userId]! + owedAmount;
    } else {
      reversalUpdates[userId] = owedAmount;
    }
  });

  // Step 2: Calculate new balance updates (same as createExpense)
  final Map<String, double> newUpdates = {};
  
  newUpdates[paidBy] = amount;
  splitMap.forEach((userId, owedAmount) {
    if (newUpdates.containsKey(userId)) {
      newUpdates[userId] = newUpdates[userId]! - owedAmount;
    } else {
      newUpdates[userId] = -owedAmount;
    }
  });

  // Step 3: Create combined update map
  final Map<String, double> combinedUpdates = {};
  
  // Combine reversal + new updates
  final allUserIds = {...reversalUpdates.keys, ...newUpdates.keys};
  for (final userId in allUserIds) {
    final reversal = reversalUpdates[userId] ?? 0.0;
    final newUpdate = newUpdates[userId] ?? 0.0;
    combinedUpdates[userId] = reversal + newUpdate;
  }

  // Step 4: Update expense and balances atomically
  final batch = _firestore.batch();

  // Update the expense document
  final expenseRef = _firestore
      .collection(FirebaseConstants.expensesCollection)
      .doc(expenseId);
  
  final updatedExpense = ExpenseModel(
    id: expenseId,
    groupId: groupId,
    description: description,
    amount: amount,
    paidBy: paidBy,
    splitMap: splitMap,
    date: oldExpense.date,  // Keep original date
  );
  
  batch.update(expenseRef, updatedExpense.toFirestore());

  // Update group balances
  final groupRef = _firestore
      .collection(FirebaseConstants.groupsCollection)
      .doc(groupId);

  combinedUpdates.forEach((userId, balanceChange) {
    batch.update(groupRef, {
      '${FirebaseConstants.groupBalancesField}.$userId':
          FieldValue.increment(balanceChange),
    });
  });

  // Commit atomically
  await batch.commit();
}
```

---

## 🎨 Step 3: Update Presentation Layer

### File: `lib/features/expense/presentation/screens/add_expense_screen.dart`

#### Update Constructor
```dart
class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  final Expense? expenseToEdit;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    this.expenseToEdit,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}
```

#### Update _AddExpenseScreenState

**Replace initState:**
```dart
@override
void initState() {
  super.initState();
  final authState = ref.read(authStateProvider);
  final currentUser = authState.value;
  
  // Check if we're editing
  if (widget.expenseToEdit != null) {
    final expense = widget.expenseToEdit!;
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _paidBy = expense.paidBy;
    _customSplits.addAll(expense.splitMap);
  } else {
    // Initialize for new expense
    _paidBy = currentUser?.id ?? '';
    
    // Get group members (need to fetch Group object)
    // Initialize custom splits with 0.0 for all members
    // This requires accessing the Group from router/parameters
  }
}
```

**Add AppBar Title Logic:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final isEditing = widget.expenseToEdit != null;
  
  return Scaffold(
    appBar: AppBar(
      title: Text(
        isEditing ? 'Edit Expense' : 'Add Expense',
      ),
    ),
    // ... rest of build method
  );
}
```

**Update Submit Button Logic:**
```dart
// In the submit/save button handler:
if (_formKey.currentState!.validate()) {
  setState(() => _isLoading = true);
  
  try {
    final description = _descriptionController.text;
    final amount = double.parse(_amountController.text);
    final splitMap = _calculateSplitMap(amount);

    if (widget.expenseToEdit != null) {
      // EDIT MODE
      await ref.read(expenseRepositoryProvider).updateExpense(
        expenseId: widget.expenseToEdit!.id,
        groupId: widget.groupId,
        description: description,
        amount: amount,
        paidBy: _paidBy!,
        splitMap: splitMap,
        oldExpense: widget.expenseToEdit!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated successfully!')),
        );
        Navigator.pop(context);
      }
    } else {
      // CREATE MODE (existing logic)
      await ref.read(expenseRepositoryProvider).createExpense(
        groupId: widget.groupId,
        description: description,
        amount: amount,
        paidBy: _paidBy!,
        splitMap: splitMap,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added successfully!')),
        );
        Navigator.pop(context);
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

---

## 📊 Update Flow Diagram

### Create Expense (Existing)
```
User Input
    ↓
Validate Form
    ↓
Calculate Split
    ↓
Call createExpense()
    ↓
Firestore Batch:
├─ Add Expense Document
└─ Update Group Balances (increment)
    ↓
Success → Pop & Show Snackbar
```

### Update Expense (New)
```
User Input (Pre-filled with old data)
    ↓
Validate Form
    ↓
Calculate Split
    ↓
Call updateExpense(oldExpense, newValues)
    ↓
Firestore Batch:
├─ Reverse OLD Balances (decrement old amounts)
├─ Apply NEW Balances (increment new amounts)
└─ Update Expense Document
    ↓
Success → Pop & Show Snackbar
```

---

## 🔄 Balance Reversal Math Example

### Scenario: Edit "Coffee" Expense

**Original Expense:**
```
Description: "Coffee"
Amount: ₹100
Paid By: Alice
Split: {alice: 0, bob: 50, charlie: 50}
```

**Group Balances After Original:**
```
alice:   +100 - 0 = +100
bob:     -50
charlie: -50
```

**Edit to New Values:**
```
Description: "Coffee & Snacks"
Amount: ₹150
Paid By: Alice
Split: {alice: 30, bob: 60, charlie: 60}
```

**Reversal Step (negate old):**
```
alice:   -100
bob:     +50
charlie: +50
```

**New Update (apply new):**
```
alice:   +150 - 30 = +120
bob:     -60
charlie: -60
```

**Combined Update (reversal + new):**
```
alice:   -100 + 120 = +20
bob:     +50 - 60 = -10
charlie: +50 - 60 = -10
```

**Final Group Balances:**
```
alice:   100 + 20 = +120 ✓ (gets back ₹120)
bob:     -50 - 10 = -60 ✓ (owes ₹60)
charlie: -50 - 10 = -60 ✓ (owes ₹60)
Total:   120 - 60 - 60 = 0 ✓ (balanced)
```

---

## 🎯 Testing Checklist

### Unit Tests (ExpenseRepository)
```dart
test('updateExpense: reverses old balances correctly', () async {
  // Setup old expense
  final oldExpense = Expense(
    id: 'exp1',
    groupId: 'grp1',
    description: 'Coffee',
    amount: 100,
    paidBy: 'alice',
    splitMap: {'bob': 50, 'charlie': 50},
    date: DateTime.now(),
  );
  
  // Call updateExpense with new values
  await repo.updateExpense(
    expenseId: 'exp1',
    groupId: 'grp1',
    description: 'Coffee & Snacks',
    amount: 150,
    paidBy: 'alice',
    splitMap: {'alice': 30, 'bob': 60, 'charlie': 60},
    oldExpense: oldExpense,
  );
  
  // Verify balances match expected combined update
  expect(finalBalance['alice'], 20);
  expect(finalBalance['bob'], -10);
  expect(finalBalance['charlie'], -10);
});
```

### Integration Tests (UI)
```dart
testWidgets('Edit expense pre-fills form', (tester) async {
  final expense = Expense(...);
  
  await tester.pumpWidget(
    AddExpenseScreen(
      groupId: 'grp1',
      expenseToEdit: expense,
    ),
  );
  
  // Verify form is pre-filled
  expect(find.text(expense.description), findsOneWidget);
  expect(find.text(expense.amount.toString()), findsOneWidget);
  expect(find.text('Edit Expense'), findsOneWidget);
});

testWidgets('Edit expense updates balances atomically', (tester) async {
  // Setup group with initial balances
  // Edit expense
  // Verify group balances updated correctly
});
```

---

## 🚀 Implementation Order

1. **Add Method Signature** to `ExpenseRepository` (domain)
2. **Implement updateExpense** in `ExpenseRepositoryImpl` (data)
3. **Update AddExpenseScreen constructor** to accept `expenseToEdit`
4. **Populate form** with expense data in `initState`
5. **Update submit logic** to call `updateExpense` when editing
6. **Update AppBar** to show "Edit Expense" when in edit mode
7. **Add success message** specific to edit action
8. **Test** create → edit → verify balance flow

---

## 📝 Key Considerations

### Firestore Batch Size
- Max 500 operations per batch
- Each balance update = 1 operation
- With ~100 members max per group, still safe

### Concurrent Edits
- If two users edit same expense simultaneously, last one wins
- Consider adding `updatedAt` timestamp for conflict detection (future enhancement)

### Date Preservation
- `updateExpense` keeps original `expense.date`
- Consider adding `editedAt` timestamp (future enhancement)

### User Permissions
- Currently, any group member can edit any expense
- Consider adding validation (only payer or admin can edit)

### Balance Verification
- After update, manually verify combined update = new - old
- Add `assert()` statements for debugging

---

## 💾 Migration Notes

### Backward Compatibility
- Existing expenses in Firestore remain unchanged
- New `updateExpense` only used for edits going forward
- No data migration needed

### Firestore Schema
No changes to existing schema:
```
/expenses/{expenseId}
├── id: string
├── groupId: string
├── description: string
├── amount: double
├── paidBy: string
├── splitMap: map<string, double>
└── date: timestamp

/groups/{groupId}
├── id: string
├── name: string
├── members: array<string>
└── balances: map<string, double>
```

---

## 🐛 Common Issues & Fixes

### Issue: Balances don't update
**Cause:** Incorrect balance field path in batch.update
**Fix:** Verify field path: `balances.{userId}`

### Issue: Edit doesn't work for expenses with custom splits
**Cause:** Not handling all split scenarios
**Fix:** Ensure reversal includes ALL users in old split

### Issue: Form not pre-filled when editing
**Cause:** initState runs before expenseToEdit is available
**Fix:** Access via `widget.expenseToEdit` in initState

### Issue: Amount shows as string instead of number
**Cause:** Using text field value directly
**Fix:** Parse with `double.parse(_amountController.text)`

---

## ✅ Verification Steps

After implementation, verify:

1. ✅ Can create new expense (existing functionality)
2. ✅ Can edit existing expense
3. ✅ Form pre-fills with old data
4. ✅ AppBar shows "Edit Expense" when editing
5. ✅ Balance reversal works correctly
6. ✅ Group balances update atomically
7. ✅ Error handling works for invalid amounts
8. ✅ User sees success snackbar
9. ✅ Navigation pops screen after save
10. ✅ Old expense document is updated

---

## 📚 Reference Files

**Domain Layer:**
- `lib/features/expense/domain/repositories/expense_repository.dart`

**Data Layer:**
- `lib/features/expense/data/repositories/expense_repository_impl.dart`
- `lib/features/expense/data/models/expense_model.dart`

**Presentation Layer:**
- `lib/features/expense/presentation/screens/add_expense_screen.dart`
- `lib/features/expense/presentation/providers/expense_providers.dart`

**Integration Points:**
- `lib/features/dashboard/presentation/widgets/expense_tile.dart` (Edit button)
- `lib/features/dashboard/presentation/screens/group_details_screen.dart` (Edit callback)

