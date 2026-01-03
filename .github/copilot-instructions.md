# Contri - AI Agent Instructions

## Project Overview
**Contri** is a Flutter expense-splitting app (Splitwise clone) using Clean Architecture, Firebase, and Riverpod. Core innovation: **client-side split calculations** with atomic Firestore batches to avoid Cloud Functions costs.

## Architecture Patterns

### Feature-Sliced Structure
```
lib/features/{auth,dashboard,expense}/
  ├── domain/          # Entities + Repository interfaces
  ├── data/            # Repository implementations + Models (Firestore converters)
  └── presentation/    # Screens, Widgets, Providers
```

### Critical Pattern: Firestore Batches with FieldValue.increment
**All write operations use atomic batches** to ensure consistency between expenses and group balances:

```dart
// REQUIRED pattern in ExpenseRepositoryImpl
final batch = _firestore.batch();
batch.set(expenseRef, expense.toFirestore());
batch.update(groupRef, {
  'balances.$userId': FieldValue.increment(balanceChange),
});
await batch.commit(); // Atomic: all or nothing
```

**Why:** Prevents race conditions in split calculations. See [expense_repository_impl.dart](lib/features/expense/data/repositories/expense_repository_impl.dart) lines 80-101 for reference.

### Domain Layer Contract
- **Entities**: Pure Dart classes with Equatable (immutable, testable)
- **Repositories**: Abstract interfaces in `domain/repositories/`
- **Models**: Data-layer only, with `toFirestore()`/`fromFirestore()` converters

Example: [ExpenseRepository](lib/features/expense/domain/repositories/expense_repository.dart) defines interface, [ExpenseRepositoryImpl](lib/features/expense/data/repositories/expense_repository_impl.dart) implements with Firestore logic.

### State Management: Riverpod StreamProviders
```dart
final groupExpensesProvider = StreamProvider.family<List<Expense>, String>((ref, groupId) {
  return ref.watch(expenseRepositoryProvider).getExpensesStream(groupId);
});
```
- **All Firestore queries** exposed as streams via Riverpod
- **Real-time updates**: UI rebuilds automatically on data changes
- See [group_providers.dart](lib/features/dashboard/presentation/providers/group_providers.dart) and [auth_providers.dart](lib/features/auth/presentation/providers/auth_providers.dart)

## Developer Workflows

### Running the App
```bash
flutter pub get
flutter run  # Uses firebase_options.dart (auto-generated)
```

### Firebase Setup (First-time)
```bash
dart pub global activate flutterfire_cli
flutterfire configure  # Creates firebase_options.dart
```
**Manual steps:** Enable Google Sign-In, create Firestore DB in test mode, add Android SHA-1 ([QUICK_START.md](QUICK_START.md) lines 25-45).

### Android Signing (for Google Sign-In)
```bash
cd android && .\gradlew.bat signingReport
```
Copy SHA-1 to Firebase Console → Project Settings → Add fingerprint.

### Code Generation
This project does NOT use `build_runner` for Riverpod code generation. Providers are manually written (e.g., `StateProvider`, `StreamProvider.family`).

## Project-Specific Conventions

### Firestore Collection Names (Constants)
```dart
// core/constants/firebase_constants.dart
usersCollection = 'users'
groupsCollection = 'groups'
expensesCollection = 'expenses'
```

### Navigation: GoRouter with Extra
```dart
// Passing objects between screens
context.push('/group-details', extra: groupObject);
```
See [app_router.dart](lib/core/router/app_router.dart) lines 66-70.

### UI Design System
- **Typography:** `GoogleFonts.lato()` everywhere (added for Splitwise-like polish)
- **Colors:** Theme-based (`Theme.of(context).colorScheme.primary`), no hardcoded hex
- **Balance Colors:**
  - Green: User is owed money (`balance > 0`)
  - Orange: User owes money (`balance < 0`)
  - Gray: Settled up (`balance == 0`)

### Split Calculation Algorithm
**DebtCalculator** ([core/utils/debt_calculator.dart](lib/core/utils/debt_calculator.dart)) uses greedy algorithm for minimal settlements:
```dart
final settlements = DebtCalculator.calculateSettlements(group.balances);
// Returns: List<Settlement> with "who owes whom how much"
```

## Critical Integration Points

### Expense Creation Flow
1. **Form Input** → [AddExpenseScreen](lib/features/expense/presentation/screens/add_expense_screen.dart)
2. **Split Calculator** → Generates `splitMap: {userId: amount}`
3. **Repository Call** → `createExpense()` with batch writes
4. **Automatic UI Update** → `groupExpensesProvider` stream notifies UI

**Key files:** [ARCHITECTURE.md](ARCHITECTURE.md) lines 133-224 (detailed flowchart).

### Balance Display
**Pre-computed balances** in group documents avoid expensive aggregations:
```dart
group.balances['userId']  // Cached value, updated via FieldValue.increment
```

### Settlement Sharing
[GroupDetailsScreen](lib/features/dashboard/presentation/screens/group_details_screen.dart) has "Settle Up" dialog that:
- Calculates settlements via `DebtCalculator`
- Generates WhatsApp share messages
- Shows settlement plan preview

## Common Tasks

### Adding New Features
1. Create feature folder in `lib/features/`
2. Define entities in `domain/entities/`
3. Create repository interface in `domain/repositories/`
4. Implement with Firestore in `data/repositories/`
5. Expose via Riverpod providers in `presentation/providers/`

### Modifying Expense Logic
⚠️ **Always use batches** when touching expenses and balances simultaneously. See [edit expense guide](EDIT_EXPENSE_GUIDE.md) for reversal + reapplication pattern.

### Testing Real-time Updates
Enable Firestore persistence in [main.dart](lib/main.dart) lines 16-23:
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## Documentation Quick Reference
- **Architecture Deep Dive:** [ARCHITECTURE.md](ARCHITECTURE.md) (338 lines with diagrams)
- **UI Components:** [DESIGN_GUIDE.md](DESIGN_GUIDE.md) (typography, spacing, color codes)
- **Implementation Status:** [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md)
- **Code Examples:** [CODE_REFERENCE.md](CODE_REFERENCE.md) (DebtCalculator usage, navigation patterns)

## Anti-Patterns to Avoid
❌ Directly updating Firestore without batches for expense operations  
❌ Hardcoding collection names (use `FirebaseConstants`)  
❌ Ignoring `FieldValue.increment` for balance updates (causes race conditions)  
❌ Creating separate commits for expense + balance updates (breaks atomicity)  
❌ Using `build_runner` (not configured in this project)

## Known Implementation Gaps
- Edit Expense: Backend exists ([expense_repository_impl.dart](lib/features/expense/data/repositories/expense_repository_impl.dart) `updateExpense()`), but UI incomplete
- Deep Links: Partial support for `contri://join/{groupId}` in [app_router.dart](lib/core/router/app_router.dart) lines 24-31
