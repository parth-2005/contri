# Persistent Family Shares Implementation

## Overview
Implemented "Persistent Family Shares" feature to allow users to define family member share ratios once during group creation, which are automatically used for faster expense entry.

## Changes Made

### 1. Domain & Data Layer

#### [Group Entity](lib/features/dashboard/domain/entities/group.dart)
- Added `final Map<String, int> defaultShares;` field
- Stores user ID to share count mapping
- Defaults to empty map `{}`
- Updated `props` to include `defaultShares`

#### [GroupModel](lib/features/dashboard/data/models/group_model.dart)
- Added `defaultShares` field to data model
- Updated `toFirestore()` to save `defaultShares` map
- Updated `fromFirestore()` to safely read `defaultShares` from Firestore (handles nulls)
- Updated `toEntity()` and `fromEntity()` conversion methods

#### [Firebase Constants](lib/core/constants/firebase_constants.dart)
- Added `groupDefaultSharesField = 'defaultShares'` constant

#### [GroupRepository Interface](lib/features/dashboard/domain/repositories/group_repository.dart)
- Updated `createGroup()` method signature to accept `Map<String, int> defaultShares`
- Parameter defaults to empty map for backward compatibility

#### [GroupRepositoryImpl](lib/features/dashboard/data/repositories/group_repository_impl.dart)
- Updated `createGroup()` to accept and pass `defaultShares` to GroupModel
- Automatically saved to Firestore during group creation

---

### 2. Presentation Layer - Group Creation

#### [CreateGroupScreen](lib/features/dashboard/presentation/screens/create_group_screen.dart)

**State Management:**
```dart
final Map<String, int> _memberShares = {}; // {email: shareCount}
```

**Member Management:**
- Added `_updateMemberShare()` method to update share count for a member
- Updated `_addMember()` to initialize share to 1 when adding
- Updated `_removeMember()` to clean up share data

**UI Enhancement:**
- Added share count input field next to each member in the members list
- TextFormField with integer-only keyboard
- Display "Share count" as subtitle
- Users can modify shares before group creation

**Group Creation:**
- Builds `defaultShares` map from `_memberShares`
- Passes `defaultShares` to `repository.createGroup()`
- Also includes current user with default share of 1

---

### 3. Presentation Layer - Expense Entry

#### [AddExpenseScreen](lib/features/expense/presentation/screens/add_expense_screen.dart)

**Split Types:**
```dart
enum SplitType { equal, custom, family }
```
- Added new `family` split type (renamed `percentage` to `family` for clarity)

**State Management:**
```dart
final Map<String, int> _memberShares = {}; // {userId: shareCount}
```

**Initialization Logic:**
```dart
// In initState:
for (final memberId in widget.group.members) {
  _memberShares[memberId] = widget.group.defaultShares[memberId] ?? 1;
}
```
- Automatically populates shares from group's `defaultShares`
- Falls back to 1 if not set

**Family Split Calculation:**
```dart
case SplitType.family:
  final totalShares = _memberShares.values.fold<int>(0, (sum, val) => sum + val);
  if (totalShares > 0) {
    for (final memberId in widget.group.members) {
      final shareCount = _memberShares[memberId] ?? 1;
      splitMap[memberId] = ((amount * shareCount) / totalShares).toStringAsFixed(2);
    }
  }
  break;
```

**UI Enhancements:**
- Added "Family" segment button between "Equal" and "Custom"
- Icon: `family_restroom`
- When "Family" split type selected:
  - Shows member name and current share count
  - Displays editable share input field
  - Shows calculated split amount for each member

---

## User Workflow

### Creating a Group
1. User creates group "Weekend Trip"
2. Adds members:
   - Alice: 3 shares (she gets 3x portions)
   - Bob: 2 shares
   - Charlie: 1 share (default)
3. Group saved with `defaultShares: {alice_id: 3, bob_id: 2, charlie_id: 1}`

### Adding an Expense
1. User goes to "Add Expense" in "Weekend Trip" group
2. Three split options available:
   - **Equal**: Splits evenly among all members
   - **Family**: Splits proportional to saved shares (3:2:1 ratio for Alice:Bob:Charlie)
   - **Custom**: Enter exact amounts per person

3. If "Family" selected:
   - ₹600 expense automatically becomes:
     - Alice: ₹300 (3/6 × 600)
     - Bob: ₹200 (2/6 × 600)
     - Charlie: ₹100 (1/6 × 600)
   - User can adjust individual shares before saving if needed

---

## Data Storage

### Firestore Structure
```
groups/{groupId}
├── name: "Weekend Trip"
├── members: [alice_id, bob_id, charlie_id]
├── balances: {alice_id: 100, bob_id: -50, charlie_id: -50}
├── defaultShares: {alice_id: 3, bob_id: 2, charlie_id: 1}  // NEW FIELD
└── createdAt: 2025-12-15
```

---

## Backward Compatibility
- Groups created without `defaultShares` will have it default to empty map `{}`
- Expense split types gracefully handle missing shares (default to 1)
- All changes are opt-in with defaults

## Benefits
✅ Faster expense entry for recurring group expenses  
✅ Accurate proportional splitting without recalculation  
✅ No need to remember share ratios  
✅ Can still override shares per expense if needed  
✅ Works with both new and existing groups
