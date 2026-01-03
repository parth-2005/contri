# AI-Ready Architecture - Visual Guide

## 📊 Architecture Diagram

### Before: Split Models
```
┌─────────────────┐       ┌─────────────────┐
│ Personal        │       │ Group           │
│ Expense         │       │ Expense         │
├─────────────────┤       ├─────────────────┤
│ id              │       │ id              │
│ description     │       │ groupId         │
│ amount          │       │ description     │
│ paidBy          │       │ amount          │
│ date            │       │ paidBy          │
│ category        │       │ split           │
│                 │       │ date            │
│                 │       │ category        │
└─────────────────┘       └─────────────────┘
    SEPARATE LOGIC          SEPARATE LOGIC
```

### After: Unified Model
```
┌──────────────────────────────────────┐
│          Expense (Unified)           │
├──────────────────────────────────────┤
│ id: String                           │
│ groupId: String? ◄──── THE KEY!      │
│ description: String                  │
│ amount: double                       │
│ paidBy: String                       │
│ split: Map<String, double>           │
│ date: DateTime                       │
│ category: String                     │
│ type: String                         │
├──────────────────────────────────────┤
│ Methods:                             │
│ • isPersonal → groupId == null       │
│ • isGroup → groupId != null          │
│ • isSplitValid → validates sum       │
└──────────────────────────────────────┘
         ONE MODEL, TWO CONTEXTS
```

---

## 🔄 Data Flow Diagram

### Personal Expense Flow
```
User Input (UI)
     │
     ▼
┌─────────────────────────────────┐
│  groupId = null                 │
│  paidBy = currentUser           │
│  split = {currentUser: amount}  │
└─────────────────────────────────┘
     │
     ▼
Repository Validation
     │
     ├─ Verify paidBy == currentUser
     ├─ Verify split.keys == [currentUser]
     └─ Verify split[currentUser] == amount
     │
     ▼
Firestore Write
     │
     ▼
┌─────────────────────────────────┐
│  expenses/{expenseId}           │
│  {                              │
│    "description": "Coffee",     │
│    "amount": 150.0,             │
│    "paidBy": "user123",         │
│    "split": {"user123": 150.0}, │
│    "category": "Food",          │
│    // NO groupId field!         │
│  }                              │
└─────────────────────────────────┘
```

### Group Expense Flow
```
User Input (UI)
     │
     ▼
┌─────────────────────────────────┐
│  groupId = "family-123"         │
│  paidBy = user1                 │
│  split = {user1: 500, user2: 500}│
└─────────────────────────────────┘
     │
     ▼
Repository Validation
     │
     ├─ Verify paidBy in group.members
     ├─ Verify split.keys ⊆ group.members
     └─ Verify Σ split.values == amount
     │
     ▼
Atomic Batch Write
     │
     ├─► Firestore: expenses/{expenseId}
     │   {
     │     "groupId": "family-123",
     │     "description": "Groceries",
     │     "amount": 1000.0,
     │     "paidBy": "user1",
     │     "split": {"user1": 500, "user2": 500},
     │   }
     │
     └─► Firestore: groups/{groupId}
         {
           "totalExpense": FieldValue.increment(1000.0),
           "balances": {
             "user1": FieldValue.increment(500.0),
             "user2": FieldValue.increment(-500.0)
           }
         }
```

---

## 🏗️ Group Entity Structure

```
┌─────────────────────────────────────────────┐
│                    Group                    │
├─────────────────────────────────────────────┤
│ id: String                                  │
│ name: String                                │
│ members: List<String>                       │
│ balances: Map<String, double>               │
│ defaultShares: Map<String, double>          │
│ createdAt: DateTime?                        │
├─────────────────────────────────────────────┤
│ NEW FIELDS (AI-Ready):                      │
├─────────────────────────────────────────────┤
│ type: GroupType ────────┐                   │
│   ├─ trip               │                   │
│   ├─ home (persistent)  │◄─ Family groups   │
│   ├─ couple             │                   │
│   └─ other              │                   │
├─────────────────────────┴───────────────────┤
│ settings: Map<String, dynamic>              │
│   Example:                                  │
│   {                                         │
│     "showAnalytics": true,                  │
│     "isPinned": true,                       │
│     "budgetLimit": 50000.0,                 │
│     "currency": "INR"                       │
│   }                                         │
├─────────────────────────────────────────────┤
│ totalExpense: double ◄── Cached sum         │
│   • Updated via FieldValue.increment()      │
│   • Avoids expensive aggregations           │
└─────────────────────────────────────────────┘
```

---

## 🎯 GroupType Decision Tree

```
Creating a new group?
         │
         ▼
    What's the purpose?
         │
    ┌────┴────┬────────┬─────────┐
    ▼         ▼        ▼         ▼
 Travel?   Home?   Couple?   Other?
    │         │        │         │
    ▼         ▼        ▼         ▼
GroupType  GroupType GroupType GroupType
  .trip      .home    .couple    .other
    │         │        │         │
    │    ┌────┴────┐   │         │
    │    ▼         ▼   │         │
    │  Persistent?  │   │         │
    │  • isPinned   │   │         │
    │  • Analytics  │   │         │
    │               │   │         │
    └───────┬───────┴───┴─────────┘
            ▼
    Store in Firestore as:
    { "type": "trip|home|couple|other" }
```

---

## 💾 Firestore Schema Comparison

### Old Schema
```json
groups/{groupId}
{
  "name": "Family",
  "members": ["user1", "user2"],
  "balances": {"user1": 500, "user2": -500},
  "defaultShares": {"user1": 1.0, "user2": 1.0}
}

expenses/{expenseId}
{
  "groupId": "family-123",
  "description": "Groceries",
  "amount": 1000.0,
  "paidBy": "user1",
  "splitMap": {"user1": 500, "user2": 500},
  "category": "Grocery"
}
```

### New Schema (AI-Ready)
```json
groups/{groupId}
{
  "name": "Family",
  "members": ["user1", "user2"],
  "balances": {"user1": 500, "user2": -500},
  "defaultShares": {"user1": 1.0, "user2": 1.0},
  "type": "home",                         ◄── NEW
  "settings": {                            ◄── NEW
    "showAnalytics": true,
    "isPinned": true
  },
  "totalExpense": 15000.0                  ◄── NEW (cached)
}

expenses/{expenseId} (Group)
{
  "groupId": "family-123",               ◄── Present for group
  "description": "Groceries",
  "amount": 1000.0,
  "paidBy": "user1",
  "splitMap": {"user1": 500, "user2": 500},
  "category": "Grocery"
}

expenses/{expenseId} (Personal)
{
  // NO groupId field!                   ◄── Absent for personal
  "description": "Coffee",
  "amount": 150.0,
  "paidBy": "user1",
  "splitMap": {"user1": 150.0},
  "category": "Food"
}
```

---

## 🔍 Query Patterns

### Get All Personal Expenses
```dart
// Repository method
Stream<List<Expense>> getUserPersonalSpending(String userId) {
  return _firestore
    .collection('expenses')
    .where('paidBy', isEqualTo: userId)
    .where('groupId', isNull: true)      ◄── Key filter
    .orderBy('date', descending: true)
    .snapshots()
    .map((snapshot) => snapshot.docs
      .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
      .toList());
}
```

### Get All Group Expenses
```dart
// Repository method
Stream<List<Expense>> getGroupSpending(String groupId) {
  return _firestore
    .collection('expenses')
    .where('groupId', isEqualTo: groupId)  ◄── Key filter
    .orderBy('date', descending: true)
    .snapshots()
    .map((snapshot) => snapshot.docs
      .map((doc) => ExpenseModel.fromFirestore(doc).toEntity())
      .toList());
}
```

### Get All Expenses (Personal + Group) for Dashboard
```dart
// Combined query in provider
final allExpensesProvider = StreamProvider.autoDispose<List<Expense>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  
  // Personal expenses
  final personalStream = ref.watch(
    expenseRepositoryProvider
  ).getUserPersonalSpending(userId);
  
  // Group expenses (from all user's groups)
  final groupStreams = ref.watch(userGroupsProvider).when(
    data: (groups) => groups.map((g) => 
      ref.watch(expenseRepositoryProvider).getGroupSpending(g.id)
    ).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
  
  // Merge streams
  return Rx.combineLatestList([personalStream, ...groupStreams])
    .map((lists) => lists.expand((l) => l).toList()
      ..sort((a, b) => b.date.compareTo(a.date)));
});
```

---

## 🎨 UI Component Structure

### Smart Expense Form (Step 4 - Not Yet Implemented)
```
┌─────────────────────────────────────────┐
│       Add Expense                       │
├─────────────────────────────────────────┤
│                                         │
│  Scope: ┌─────────────────────────────┐│
│         │ ◉ Personal                   ││
│         │ ○ Family                     ││
│         │ ○ Trip to Goa                ││
│         │ ○ Couple Expenses            ││
│         └─────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┤
│  │ IF Personal Selected:               │
│  │   • Hide "Paid By" field            │
│  │   • Hide "Split" fields             │
│  │   • Force: paidBy = Me              │
│  │   • Force: split = {Me: amount}     │
│  └─────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────────┤
│  │ IF Group Selected:                  │
│  │   • Show "Paid By" dropdown         │
│  │   • Show "Split" inputs/sliders     │
│  │   • Validate: sum = total           │
│  └─────────────────────────────────────┤
│                                         │
│  Description: [________________]        │
│  Amount: [________]                     │
│  Category: [Dropdown▼]                  │
│  Date: [01/03/2026]                     │
│                                         │
│  Paid By: [User1 ▼] ◄── Conditional   │
│                                         │
│  Split:                 ◄── Conditional │
│    User1: ████████░░ 60%                │
│    User2: █████░░░░░ 40%                │
│                                         │
│  [Cancel]            [Add Expense]      │
└─────────────────────────────────────────┘
```

---

## 📈 Analytics Dashboard (Step 5 - Not Yet Implemented)

```
┌─────────────────────────────────────────┐
│  Family Group Analytics                 │
├─────────────────────────────────────────┤
│                                         │
│  Total Spent:  ₹15,000                  │
│  Total Expenses: 23                     │
│  Average: ₹652/expense                  │
│                                         │
│  Category Breakdown:                    │
│  ┌───────────────────────────┐          │
│  │ Grocery      ████████ 45% │          │
│  │ Fuel         ████░░░░ 25% │          │
│  │ Entertainment ███░░░░░ 20%│          │
│  │ Other        ██░░░░░░ 10% │          │
│  └───────────────────────────┘          │
│                                         │
│  Spending Curve (Last 30 Days):         │
│  ┌───────────────────────────┐          │
│  │      ╱╲                   │          │
│  │     ╱  ╲    ╱╲            │          │
│  │    ╱    ╲  ╱  ╲     ╱╲    │          │
│  │   ╱      ╲╱    ╲   ╱  ╲   │          │
│  │  ╱            ╲╲ ╱    ╲  │          │
│  │ ╱               ╲╱      ╲ │          │
│  └───────────────────────────┘          │
│                                         │
│  Per-Member Spending:                   │
│  • Dad: ₹7,500 (50%)                   │
│  • Mom: ₹4,500 (30%)                   │
│  • Child: ₹3,000 (20%)                 │
│                                         │
└─────────────────────────────────────────┘
```

---

## 🔐 Validation Rules

### Personal Expense Validation
```dart
class PersonalExpenseValidator {
  ValidationResult validate(Expense expense, String currentUserId) {
    final errors = <String>[];
    
    // Rule 1: groupId must be null
    if (expense.groupId != null) {
      errors.add('Personal expense cannot have groupId');
    }
    
    // Rule 2: paidBy must be current user
    if (expense.paidBy != currentUserId) {
      errors.add('Personal expense must be paid by current user');
    }
    
    // Rule 3: split must only contain current user
    if (expense.split.length != 1 || 
        !expense.split.containsKey(currentUserId)) {
      errors.add('Personal expense must be split only with self');
    }
    
    // Rule 4: split amount must equal total
    if ((expense.split[currentUserId] ?? 0.0) != expense.amount) {
      errors.add('Split amount must equal total amount');
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
```

### Group Expense Validation
```dart
class GroupExpenseValidator {
  ValidationResult validate(Expense expense, Group group) {
    final errors = <String>[];
    
    // Rule 1: groupId must not be null
    if (expense.groupId == null) {
      errors.add('Group expense must have groupId');
    }
    
    // Rule 2: paidBy must be a group member
    if (!group.members.contains(expense.paidBy)) {
      errors.add('Payer must be a group member');
    }
    
    // Rule 3: All split users must be group members
    for (final userId in expense.split.keys) {
      if (!group.members.contains(userId)) {
        errors.add('Split user $userId is not a group member');
      }
    }
    
    // Rule 4: Split must sum to total amount
    final splitTotal = expense.split.values
      .fold<double>(0.0, (sum, amount) => sum + amount);
    if ((splitTotal - expense.amount).abs() > 0.01) {
      errors.add('Split total ($splitTotal) must equal amount (${expense.amount})');
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
```

---

## 🧪 Test Cases

### Domain Entity Tests
```dart
test('Expense.isPersonal returns true when groupId is null', () {
  final expense = Expense(
    id: '1',
    groupId: null,
    description: 'Coffee',
    amount: 150.0,
    paidBy: 'user1',
    split: {'user1': 150.0},
    date: DateTime.now(),
    category: 'Food',
    type: 'personal',
  );
  
  expect(expense.isPersonal, true);
  expect(expense.isGroup, false);
});

test('Expense.isSplitValid returns true when split sums to total', () {
  final expense = Expense(
    id: '1',
    groupId: 'group1',
    description: 'Groceries',
    amount: 1000.0,
    paidBy: 'user1',
    split: {'user1': 600.0, 'user2': 400.0},
    date: DateTime.now(),
    category: 'Grocery',
    type: 'group',
  );
  
  expect(expense.isSplitValid, true);
});

test('Group.isPersistent returns true for home type', () {
  final group = Group(
    id: '1',
    name: 'Family',
    members: ['user1', 'user2'],
    balances: {},
    type: GroupType.home,
  );
  
  expect(group.isPersistent, true);
});

test('Group.showAnalytics returns setting value', () {
  final group = Group(
    id: '1',
    name: 'Family',
    members: ['user1', 'user2'],
    balances: {},
    settings: {'showAnalytics': true},
  );
  
  expect(group.showAnalytics, true);
});
```

---

## 🚀 Performance Considerations

### 1. **Cached totalExpense**
```
Without Cache:
  User views group list
    → Fetch all groups
    → For each group, query all expenses
    → Sum amounts
    → Display
  ⏱️ Time: O(n * m) where n=groups, m=avg expenses

With Cache:
  User views group list
    → Fetch all groups (includes totalExpense field)
    → Display
  ⏱️ Time: O(n) - 10x faster!
```

### 2. **Indexed Queries**
```dart
// Required Firestore Indexes:

// Personal expenses by user
expenses:
  - paidBy: ASC
  - groupId: ASC  // For isNull check
  - date: DESC

// Group expenses
expenses:
  - groupId: ASC
  - date: DESC
```

### 3. **Batch Writes for Consistency**
```dart
// GOOD: Atomic update
final batch = _firestore.batch();
batch.set(expenseRef, expense.toFirestore());
batch.update(groupRef, {
  'totalExpense': FieldValue.increment(expense.amount),
  'balances.${expense.paidBy}': FieldValue.increment(expense.amount),
});
await batch.commit(); // All or nothing

// BAD: Race conditions possible
await _firestore.collection('expenses').add(expense.toFirestore());
await _firestore.collection('groups').doc(groupId).update({
  'totalExpense': FieldValue.increment(expense.amount),
});
```

---

## 📱 Migration Path

### Phase 1: Domain Models (✅ Completed)
- Updated Group entity
- Updated Expense entity
- Updated data models
- Added Firebase constants

### Phase 2: Repository Logic (Next)
- Implement validation rules
- Update createExpense() with branching logic
- Add getPersonalExpenses() method
- Update batch writes for totalExpense

### Phase 3: UI Updates
- Add scope selector to AddExpenseScreen
- Implement reactive form fields
- Update expense list to show both types
- Add personal expenses tab in dashboard

### Phase 4: Analytics
- Create GroupAnalyticsService
- Implement category breakdown calculator
- Create spending curve generator
- Build analytics UI screen

### Phase 5: Data Migration (Optional)
- Backfill totalExpense for existing groups
- Add default type/settings to existing groups
- No migration needed for expenses (backward compatible)

---

*Generated: January 3, 2026*
*Architecture Version: 2.0 - AI-Ready*
