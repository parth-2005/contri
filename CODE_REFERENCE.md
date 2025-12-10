# Contri Pro - Code Reference & Integration Guide

## 🎯 Quick Integration Checklist

- [x] **DebtCalculator** created in `lib/core/utils/debt_calculator.dart`
- [x] **GroupDetailsScreen** rewritten with SliverAppBar and settlement plan
- [x] **ExpenseTile** widget created for Splitwise-style UI
- [x] **google_fonts** added to `pubspec.yaml`
- [ ] **Edit Expense Engine** - Backend repository methods (TODO)
- [ ] **AddExpenseScreen** - Edit mode support (TODO)

---

## 📊 DebtCalculator Usage Examples

### Basic Settlement Calculation
```dart
import 'package:contri/core/utils/debt_calculator.dart';

// Group balances from Firestore
final balances = {
  "alice": 100.0,      // Alice is owed ₹100
  "bob": -50.0,        // Bob owes ₹50
  "charlie": -50.0,    // Charlie owes ₹50
};

// Calculate minimum settlements
final settlements = DebtCalculator.calculateSettlements(balances);
// Result:
// [
//   Settlement(bob → alice, ₹50),
//   Settlement(charlie → alice, ₹50)
// ]
```

### Display Settlement in UI
```dart
final settlements = DebtCalculator.calculateSettlements(group.balances);

for (final settlement in settlements) {
  final display = DebtCalculator.formatSettlement(
    settlement,
    {"alice": "Alice", "bob": "Bob"},
  );
  print(display); // "Bob owes Alice ₹50.00"
}
```

### Share via WhatsApp
```dart
final message = DebtCalculator.getWhatsAppMessage(
  settlement,
  {"alice": "Alice", "bob": "Bob"},
  "Weekend Trip",
);
// Output: "Bob owes Alice ₹50.00 in Weekend Trip"

Share.share(message);
```

---

## 🎨 GroupDetailsScreen Integration

### Navigation to Screen
```dart
// From any screen, navigate to group details
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GroupDetailsScreen(
      group: groupObject, // Pass Group entity
    ),
  ),
);
```

### Provider Usage
The screen automatically handles:
- `groupExpensesProvider`: Streams expenses for the group
- `authStateProvider`: Gets current user info
- `memberProfilesProvider`: Fetches member details

```dart
// These are already inside GroupDetailsScreen
final expensesAsync = ref.watch(groupExpensesProvider(group.id));
final currentUser = ref.watch(authStateProvider).value;
final membersAsync = ref.watch(memberProfilesProvider(group.members));
```

### Settlement Plan Dialog
Triggered by "Settle Up" button:
```dart
_showSettlementPlan(context, ref, currentUser?.id);
// Shows:
// 1. Settlement list with "A → B: ₹X"
// 2. WhatsApp share button for each settlement
// 3. Check icon if everyone is settled up
```

### Add/Edit Expense Callbacks
```dart
// Add new expense
_addExpense(context, ref);
// Navigates to: AddExpenseScreen(groupId: group.id)

// Edit existing expense
_editExpense(context, ref, expense);
// Navigates to: AddExpenseScreen(
//   groupId: group.id,
//   expenseToEdit: expense,
// )
```

---

## 🧩 ExpenseTile Integration

### Using ExpenseTile in a List
```dart
SliverList(
  delegate: SliverChildBuilderDelegate(
    (context, index) {
      final expense = expenses[index];
      return ExpenseTile(
        expense: expense,
        members: membersMap,
        currentUserId: currentUser?.id,
        onEdit: () {
          // Handle edit action
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                groupId: group.id,
                expenseToEdit: expense,
              ),
            ),
          );
        },
      );
    },
    childCount: expenses.length,
  ),
)
```

### Customization
```dart
// Change border radius
borderRadius: BorderRadius.circular(12),

// Change highlight color when expanded
color: _isExpanded 
    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
    : Colors.white,
```

---

## 🔄 Settlement Calculation Logic Breakdown

### Step 1: Find Maximum Debtor (Person owed most)
```dart
String? maxDebtorId;
double maxDebtorAmount = 0;

for (final entry in balancesCopy.entries) {
  if (entry.value > maxDebtorAmount) {
    maxDebtorAmount = entry.value;
    maxDebtorId = entry.key;
  }
}
// maxDebtorId = "alice", maxDebtorAmount = 100.0
```

### Step 2: Find Maximum Creditor (Person who owes most)
```dart
String? maxCreditorId;
double maxCreditorAmount = 0;

for (final entry in balancesCopy.entries) {
  if (entry.value < 0 && entry.value.abs() > maxCreditorAmount) {
    maxCreditorAmount = entry.value.abs();
    maxCreditorId = entry.key;
  }
}
// maxCreditorId = "bob", maxCreditorAmount = 50.0
```

### Step 3: Settle the Minimum Amount
```dart
final settleAmount = min(100.0, 50.0); // = 50.0

settlements.add(Settlement(
  fromUserId: "bob",
  toUserId: "alice",
  amount: 50.0,
));

// Update balances
balancesCopy["alice"] = 100.0 - 50.0 = 50.0;
balancesCopy["bob"] = -50.0 + 50.0 = 0.0; // Removed next iteration
```

### Step 4: Repeat Until No Debts
Continues until all balances ≈ 0 (within ₹0.01 tolerance)

---

## 🎯 Color Coding System (ExpenseTile)

### Green (You Lent Money)
```dart
// Triggered when:
// - Current user is the payer AND
// - Someone else is in the split
// Example: "You lent ₹100"
color: Colors.green.shade700
```

### Orange (You Owe Money)
```dart
// Triggered when:
// - Expense was paid by someone else AND
// - Current user is in the split
// Example: "You borrowed ₹50"
color: Colors.orange.shade700
```

### Gray (Not Involved)
```dart
// Triggered when:
// - Current user is NOT in the split AND
// - Current user didn't pay
// Example: "Not involved"
color: Colors.grey.shade600
```

---

## 📱 Widget Layout Structure

### GroupDetailsScreen Hierarchy
```
Scaffold
└── CustomScrollView
    ├── SliverAppBar (expandable, pinned)
    │   ├── FlexibleSpaceBar
    │   │   ├── Balance Title
    │   │   ├── Balance Amount (huge)
    │   │   ├── Balance Status Text
    │   │   └── Settle Up Button
    │   └── Actions (Share, Info)
    │
    ├── SliverToBoxAdapter
    │   └── Settlement Plan Container
    │       ├── Settlement summary (2 items)
    │       └── "+N more" indicator
    │
    ├── SliverList
    │   └── ExpenseTile × N
    │
    └── SliverToBoxAdapter
        └── SizedBox (80dp spacing for FAB)

FloatingActionButton (Add Expense)
```

### ExpenseTile Internal Structure
```
Container (Border, Border Radius)
├── InkWell (Tap to expand)
│   └── Row
│       ├── Date Box (50×50)
│       │   ├── MMM (11px bold)
│       │   └── DD (14px bold)
│       │
│       ├── Column (Description + Payer)
│       │   ├── Description (14px bold)
│       │   └── "Paid by [Name]" (12px gray)
│       │
│       ├── Column (Status + Amount)
│       │   ├── "You lent/borrowed" (12px colored)
│       │   └── Amount (14px colored bold)
│       │
│       └── Expand Icon
│
└── [if expanded]
    ├── Divider
    └── Expanded Content
        ├── Total Amount Row
        ├── Date Row
        ├── Split Details
        │   └── Grid of members and amounts
        └── Edit Expense Button
```

---

## 🔗 Data Flow

```
Firestore
    ↓
GroupExpensesProvider (StreamProvider)
    ↓
GroupDetailsScreen (watches provider)
    ↓
[Processes with DebtCalculator]
    ↓
Renders:
├── Settlement Plan (via DebtCalculator)
├── Expense List (via SliverList)
└── Individual ExpenseTiles
    ├── Shows user's role (lent/owed/uninvolved)
    └── Expandable details with edit button
```

---

## ✅ Testing Scenarios

### Test 1: Settlement Calculation
```dart
void testSettlementCalculation() {
  final balances = {
    "alice": 100.0,
    "bob": -50.0,
    "charlie": -50.0,
  };
  
  final settlements = DebtCalculator.calculateSettlements(balances);
  
  expect(settlements.length, 2);
  expect(settlements[0].fromUserId, "bob");
  expect(settlements[0].toUserId, "alice");
  expect(settlements[0].amount, 50.0);
}
```

### Test 2: Color Coding
```dart
// Test in ExpenseTile state
final (status, amount, color) = _getUserExpenseStatus();

// When user is payer
expect(status, "You lent");
expect(color, Colors.green.shade700);

// When user is in split
expect(status, "You borrowed");
expect(color, Colors.orange.shade700);
```

### Test 3: UI Responsiveness
- Header should collapse smoothly when scrolling
- Settlement plan should be visible at top
- Expense tiles should expand/collapse without lag
- "Settle Up" dialog should load and display settlements

---

## 🐛 Known Considerations

1. **Settlement Precision:** Uses 0.01 (₹0.01) tolerance for zero balance detection
2. **Date Formatting:** Uses `DateFormat('MMM')` and `DateFormat('dd')` for consistency
3. **Member Names:** Falls back to User ID if member data not loaded
4. **Async Handling:** Uses `.when()` for all AsyncValues with proper loading/error states
5. **WhatsApp Messages:** Plain text format suitable for sharing

---

## 📚 Related Files

**Not Modified (Still Working):**
- `lib/features/expense/domain/entities/expense.dart`
- `lib/features/expense/domain/repositories/expense_repository.dart`
- `lib/features/dashboard/domain/entities/group.dart`
- `lib/features/auth/presentation/providers/auth_providers.dart`
- `lib/core/utils/currency_formatter.dart`

**Awaiting Updates:**
- `lib/features/expense/presentation/screens/add_expense_screen.dart` (edit mode)
- `lib/features/expense/data/repositories/expense_repository_impl.dart` (updateExpense)
- `lib/features/expense/domain/repositories/expense_repository.dart` (updateExpense signature)

---

## 🚀 Next Implementation Order

1. Add `updateExpense()` method to `ExpenseRepository` (domain)
2. Implement `updateExpense()` in `ExpenseRepositoryImpl` (data)
3. Update `AddExpenseScreen` to support edit mode with `expenseToEdit` parameter
4. Test edit flow end-to-end
5. Verify all balance updates are correct
6. Run comprehensive testing suite

---

## 📞 Quick Reference: Import Statements

```dart
// Debt Calculator
import 'package:contri/core/utils/debt_calculator.dart';

// Group Details Screen
import 'package:contri/features/dashboard/presentation/screens/group_details_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Expense Tile
import 'package:contri/features/dashboard/presentation/widgets/expense_tile.dart';

// Currency Formatting
import 'package:contri/core/utils/currency_formatter.dart';
```

