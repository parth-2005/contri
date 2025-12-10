# Contri - Setup Summary

## ✅ Completed Setup

### 1. Dependencies Installed
All required packages have been added via `flutter pub add`:
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`
- State Management: `flutter_riverpod`, `riverpod_annotation`
- Navigation: `go_router`
- Utilities: `uuid`, `intl`, `equatable`, `shared_preferences`
- Dev Tools: `build_runner`, `riverpod_generator`, `flutter_lints`

### 2. Theme Configuration
Created **Indian Minimalist Theme** in `lib/core/theme/app_theme.dart`:
- Primary Color: Teal Green (#00897B)
- Background: Off-White (#F5F5F0)
- Secondary: Beige (#E0DCD0)
- Configured AppBar, Cards, FAB with rounded corners and proper elevation

### 3. Clean Architecture Structure
```
lib/
├── core/
│   ├── theme/
│   │   └── app_theme.dart
│   ├── constants/
│   │   └── firebase_constants.dart
│   └── utils/
│       └── currency_formatter.dart
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   ├── dashboard/
│   │   ├── domain/
│   │   │   ├── entities/group.dart
│   │   │   └── repositories/group_repository.dart
│   │   ├── data/
│   │   │   ├── models/group_model.dart
│   │   │   └── repositories/group_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/group_providers.dart
│   │       ├── screens/dashboard_screen.dart
│   │       └── widgets/group_card.dart
│   └── expense/
│       ├── domain/
│       │   ├── entities/expense.dart
│       │   └── repositories/expense_repository.dart
│       ├── data/
│       │   ├── models/expense_model.dart
│       │   └── repositories/expense_repository_impl.dart ⭐ CORE LOGIC
│       └── presentation/
└── main.dart
```

### 4. **⭐ Core Split Logic Implementation**
File: `lib/features/expense/data/repositories/expense_repository_impl.dart`

**Key Features:**
- **Client-Side Calculation**: All split math happens in the app (zero Cloud Function cost)
- **Atomic Updates**: Uses Firestore batch writes with `FieldValue.increment()`
- **Read-Optimized**: Updates denormalized `balances` map in Group document
- **Logic Flow**:
  1. User creates expense
  2. Calculate net impact: Payer gets +amount, splitters get -amount
  3. Batch update: Create expense doc + update group balances atomically

**Example:**
```dart
// If Alice pays ₹300 for groceries split equally among Alice, Bob, Charlie:
// splitMap = { alice: 100, bob: 100, charlie: 100 }
// Balance updates:
// - alice: +300 (paid) - 100 (owes) = +200
// - bob: -100
// - charlie: -100
```

### 5. Dashboard Screen
Created `DashboardScreen` with:
- ListView of group cards showing balances
- Color-coded balance chips (Green = Gets Back, Orange = Owes, Gray = Settled)
- Empty state with call-to-action
- Floating Action Button for quick adds
- Currency formatting in Indian Rupee (₹)

## 🔧 Next Steps

### Immediate (Before Running)
1. **Configure Firebase:**
   ```bash
   # Install FlutterFire CLI globally
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure
   ```
   This will generate `firebase_options.dart` required by Firebase.

2. **Enable Firestore & Authentication:**
   - Go to Firebase Console
   - Enable Google Sign-In in Authentication
   - Enable Firestore Database (Start in test mode for development)

### Recommended Next Features
1. **Authentication Flow**: Login screen with Google Sign-In
2. **Create Group**: Dialog/Screen to add new groups
3. **Add Expense**: Screen with split calculator
4. **Group Details**: View all expenses in a group
5. **Settlement Suggestions**: Calculate optimal payment paths
6. **Offline Support**: Use `shared_preferences` for caching

## 📊 Database Schema (Firestore)

### Collection: `users/{uid}`
```javascript
{
  name: string,
  email: string,
  photoUrl: string,
  total_owed: number  // Optional cache
}
```

### Collection: `groups/{groupId}`
```javascript
{
  name: string,
  members: [uid1, uid2, ...],
  balances: {
    uid1: 250.50,   // Gets back ₹250.50
    uid2: -150.00,  // Owes ₹150
    uid3: -100.50   // Owes ₹100.50
  },
  createdAt: timestamp
}
```

### Collection: `expenses/{expenseId}`
```javascript
{
  groupId: string,
  description: string,
  amount: number,
  paidBy: uid,
  splitMap: {
    uid1: 100,  // uid1 owes ₹100
    uid2: 100,  // uid2 owes ₹100
    uid3: 100   // uid3 owes ₹100
  },
  date: timestamp,
  createdAt: timestamp
}
```

## 🚀 Running the App

```bash
# Get dependencies (already done)
flutter pub get

# Configure Firebase (MUST DO)
flutterfire configure

# Run the app
flutter run
```

## 💡 Architecture Highlights

- **Zero Cost**: No Cloud Functions - all logic on client
- **Offline First**: Ready for offline caching with `shared_preferences`
- **Atomic Updates**: `FieldValue.increment()` ensures consistency
- **Read-Optimized**: Denormalized balances prevent expensive queries
- **Clean Architecture**: Easy to test and maintain

---

**Status**: ✅ Core architecture complete. Ready for Firebase configuration and feature additions.
