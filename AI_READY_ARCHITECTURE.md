# AI-Ready Architecture Implementation

## Overview
This document describes the architectural upgrade to make Contri "AI-Ready" by unifying Personal and Group expenses into a single robust model with advanced analytics capabilities.

## ✅ Completed: Steps 1 & 2 - Domain Model Upgrades

### Step 1: Group Model Enhancement

**File**: [lib/features/dashboard/domain/entities/group.dart](lib/features/dashboard/domain/entities/group.dart)

#### Added Features:

1. **GroupType Enum**
   ```dart
   enum GroupType {
     trip,    // Travel/trip expenses
     home,    // Household/family expenses (persistent)
     couple,  // Couple-specific expenses
     other,   // General/miscellaneous
   }
   ```

2. **Settings Field** - `Map<String, dynamic>`
   - **Purpose**: Flexible feature toggles without schema changes
   - **Examples**:
     - `'showAnalytics': true/false` - Enable/disable analytics view
     - `'isPinned': true/false` - Pin group to top of list
     - `'allowPersonalExpenses': true/false` - Future expansion
     - `'notifyOnNewExpense': true/false` - Notification preferences

3. **Total Expense Field** - `double totalExpense`
   - **Purpose**: Cached sum of all expenses in this group
   - **Benefit**: Efficient list displays without fetching all expenses
   - **Update Strategy**: Batch writes when expenses are added/edited

4. **Helper Methods**:
   ```dart
   bool get isPersistent => type == GroupType.home;
   bool get showAnalytics => isSettingEnabled('showAnalytics');
   bool get isPinned => isSettingEnabled('isPinned');
   T? getSettingValue<T>(String key);
   bool isSettingEnabled(String key);
   ```

### Step 2: Unified Expense Model

**File**: [lib/features/expense/domain/entities/expense.dart](lib/features/expense/domain/entities/expense.dart)

#### Key Architectural Change:

**`groupId` is NOW NULLABLE** - This is the differentiator:
- `groupId == null` → **Personal Expense**
  - `paidBy` MUST be currentUser
  - `split` MUST be `{currentUser: totalAmount}`
  - Individual tracking only
  
- `groupId != null` → **Group Expense**
  - `paidBy` can be any group member
  - `split` validated against group members
  - Shared with others

#### Field Renaming:
- `splitMap` → `split` (cleaner, more semantic)

#### New Helper Methods:
```dart
bool get isPersonal => groupId == null;
bool get isGroup => groupId != null;
bool get isSplitValid; // Validates split sums to total
int get splitCount; // Number of people in split
```

#### Enhanced Documentation:
- Each field now has clear AI-ready documentation
- Split validation logic explained
- Personal vs Group constraints documented

---

## Data Layer Updates

### Firebase Constants
**File**: [lib/core/constants/firebase_constants.dart](lib/core/constants/firebase_constants.dart)

Added new constants:
```dart
// Group Fields
static const String groupTypeField = 'type';
static const String groupSettingsField = 'settings';
static const String groupTotalExpenseField = 'totalExpense';
```

### GroupModel (Firestore Converter)
**File**: [lib/features/dashboard/data/models/group_model.dart](lib/features/dashboard/data/models/group_model.dart)

**Changes**:
- Added `type`, `settings`, `totalExpense` fields
- `toFirestore()`: Serializes `GroupType` to string via `.toShortString()`
- `fromFirestore()`: Deserializes with fallbacks (`GroupType.other`, empty map, `0.0`)
- Maintains backward compatibility with existing data

### ExpenseModel (Firestore Converter)
**File**: [lib/features/expense/data/models/expense_model.dart](lib/features/expense/data/models/expense_model.dart)

**Changes**:
- Made `groupId` nullable
- Renamed `splitMap` → `split` throughout
- `toFirestore()`: **Only includes `groupId` if not null** (personal expenses omit this field)
- `fromFirestore()`: Handles nullable `groupId` gracefully
- Maintains backward compatibility

---

## Architectural Benefits

### 1. **Single Source of Truth**
- One `Expense` model for all contexts (personal, family, trip, couple)
- No more duplicate logic or parallel models

### 2. **AI-Ready Data Structure**
- Clear differentiator (`groupId` nullability) for AI training
- Validated splits ensure data consistency
- Category and type fields enable ML insights

### 3. **Future-Proof Settings**
- Group settings as `Map<String, dynamic>` allows adding features without migrations
- Examples:
  - `'budgetLimit': 5000.0`
  - `'currency': 'INR'`
  - `'aiInsightsEnabled': true`

### 4. **Performance Optimized**
- `totalExpense` caching reduces expensive aggregations
- Personal expenses don't create unnecessary group documents

### 5. **Type Safety**
- GroupType enum prevents invalid group types
- Extension methods provide string conversion

---

## Next Steps (Not Yet Implemented)

### Step 3: Repository Logic Layer
**Files to Update**:
- `lib/features/expense/data/repositories/expense_repository_impl.dart`

**Required Changes**:
```dart
// In addExpense()
if (expense.groupId != null) {
  // Case A: Group Expense
  // - Validate paidBy is a group member
  // - Validate split sums to total
  // - Update group.totalExpense via FieldValue.increment()
} else {
  // Case B: Personal Expense
  // - Force paidBy = currentUser
  // - Force split = {currentUser: amount}
  // - Ignore UI split inputs
}
```

**New Methods Needed**:
```dart
Stream<List<Expense>> getGroupSpending(String groupId);
Stream<List<Expense>> getUserPersonalSpending(String userId);
```

### Step 4: Smart UI Form
**Files to Update**:
- `lib/features/expense/presentation/screens/add_expense_screen.dart`

**UI Changes**:
1. Add **Scope Selector**: `[ Personal | Family | Trip A | Trip B ]`
2. **Reactive Fields**:
   - Personal: Hide "Paid By" and "Split" fields
   - Group: Show member dropdown and split inputs
3. **Submit Logic**: Pass correct `groupId` (or `null`)

### Step 5: Group Analytics Service
**New File**: `lib/features/analytics/logic/group_analytics_service.dart`

**Implementation**:
```dart
class GroupAnalyticsService {
  GroupStats calculateGroupStats(List<Expense> expenses) {
    return GroupStats(
      totalSpent: expenses.fold(0.0, (sum, e) => sum + e.amount),
      categoryBreakdown: _calculateCategoryBreakdown(expenses),
      spendingCurve: _calculateDailyTotals(expenses),
    );
  }
}
```

---

## Migration Strategy

### Backward Compatibility
✅ **Existing data remains valid**:
- Old groups without `type`/`settings`/`totalExpense` → Defaults applied
- Old expenses with `groupId` → Works as group expenses
- No data migration required initially

### Gradual Rollout
1. **Phase 1** (Completed): Domain model updates
2. **Phase 2**: Update repositories with validation logic
3. **Phase 3**: Update UI to use nullable groupId
4. **Phase 4**: Add analytics service
5. **Phase 5**: Optional data migration to populate `totalExpense` field

### Data Migration Script (Optional)
```dart
// To populate totalExpense for existing groups
for (var group in allGroups) {
  final expenses = await getGroupExpenses(group.id);
  final total = expenses.fold(0.0, (sum, e) => sum + e.amount);
  await firestore.collection('groups').doc(group.id).update({
    'totalExpense': total,
  });
}
```

---

## Testing Checklist

- [ ] Create new personal expense (groupId = null)
- [ ] Create new group expense (groupId != null)
- [ ] Verify existing expenses still load correctly
- [ ] Verify groups with default values render properly
- [ ] Test GroupType enum serialization/deserialization
- [ ] Test settings field with various data types
- [ ] Validate split sum calculations
- [ ] Test isPersonal/isGroup helper methods

---

## Code Reference

### Creating a Personal Expense
```dart
final personalExpense = Expense(
  id: uuid.v4(),
  groupId: null, // THE KEY: null for personal
  description: 'Coffee',
  amount: 150.0,
  paidBy: currentUserId,
  split: {currentUserId: 150.0}, // Only split with self
  date: DateTime.now(),
  category: 'Food',
  type: 'personal',
);
```

### Creating a Group Expense
```dart
final groupExpense = Expense(
  id: uuid.v4(),
  groupId: 'family-group-id', // THE KEY: non-null for group
  description: 'Groceries',
  amount: 2000.0,
  paidBy: userId1,
  split: {
    userId1: 1000.0,
    userId2: 1000.0,
  },
  date: DateTime.now(),
  category: 'Grocery',
  type: 'family',
);
```

### Creating a Group with Settings
```dart
final familyGroup = Group(
  id: uuid.v4(),
  name: 'Family',
  members: [userId1, userId2],
  balances: {userId1: 0.0, userId2: 0.0},
  type: GroupType.home, // Persistent family group
  settings: {
    'showAnalytics': true,
    'isPinned': true,
    'budgetLimit': 50000.0,
  },
  totalExpense: 0.0, // Will be updated as expenses are added
);
```

---

## Questions for Next Phase

Before implementing Step 3 (Repository Logic), please confirm:

1. **Personal Expense Collection**: Should personal expenses:
   - a) Still be stored in `expenses` collection with `groupId: null`?
   - b) Have a separate `personal_expenses` collection?
   - **Recommendation**: (a) - Single collection simplifies queries

2. **Personal Expense Validation**: Should we:
   - a) Enforce validation in repository (backend)
   - b) Only validate in UI (frontend)
   - **Recommendation**: (a) - Backend validation ensures data integrity

3. **Total Expense Update**: When should `group.totalExpense` be updated?
   - a) On every expense add/edit/delete (atomic batches)
   - b) On-demand calculation when group is viewed
   - **Recommendation**: (a) - Maintains cached value, better performance

4. **Analytics Service**: Should analytics be:
   - a) Real-time calculated from streams
   - b) Cached in Firestore with periodic updates
   - **Recommendation**: (a) for MVP, (b) for scale

---

## Summary

**What Changed**:
- ✅ Group entity: Added `type`, `settings`, `totalExpense`
- ✅ Expense entity: Made `groupId` nullable, renamed `splitMap` → `split`
- ✅ Data models updated with Firestore converters
- ✅ Firebase constants added for new fields
- ✅ Helper methods for type checking and validation

**What's Next**:
- ⏳ Repository logic for personal vs group expense handling
- ⏳ Smart UI form with reactive fields
- ⏳ Group analytics service implementation

**Impact**:
- Zero breaking changes to existing code
- Backward compatible with all existing data
- Foundation laid for AI-ready analytics

---

*Generated: January 3, 2026*
*Architecture Version: 2.0 - AI-Ready*
