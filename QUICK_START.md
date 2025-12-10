# Quick Start Guide - Contri

## 1️⃣ Configure Firebase (First Time Setup)

```bash
# Install FlutterFire CLI globally (one-time)
dart pub global activate flutterfire_cli

# Configure Firebase for your project
cd E:\projects\Lakshya\split-it\contri
flutterfire configure
```

This will:
- ✅ Create `lib/firebase_options.dart` 
- ✅ Connect to your Firebase project
- ✅ Enable necessary services

---

## 2️⃣ Firebase Console Setup

Go to [Firebase Console](https://console.firebase.google.com):

### A. Authentication
1. Go to **Authentication** → **Sign-in method**
2. Click **Google**
3. Enable it and add your email as test user
4. Set your app SHA-1 fingerprint for Android

### B. Firestore Database
1. Go to **Firestore Database**
2. Click **Create Database**
3. Start in **Test mode** (for development)
4. Choose a region close to your users
5. Click **Create**

### C. Enable APIs
1. Make sure these are enabled:
   - Google Sign-In API
   - Firebase Authentication
   - Cloud Firestore

---

## 3️⃣ Run the App

```bash
# Install dependencies (already done)
flutter pub get

# Run on connected device/emulator
flutter run
```

---

## 4️⃣ Test Flow

### First Launch:
1. **Login Screen** appears with Google Sign-In button
2. Click **"Continue with Google"**
3. Select your test Google account
4. Redirects to **Dashboard** (empty at first)

### Create a Group:
1. Click **"New Group"** FAB
2. Enter group name (e.g., "Flat 402")
3. (Optional) Add member emails
4. Click **"Create Group"**
5. Group appears in dashboard

### Add an Expense:
1. Click group card
2. Click **"Add Expense"** FAB
3. Fill in:
   - Description (e.g., "Groceries")
   - Amount (e.g., "300")
   - Paid by (select member)
   - Split type (Equal or Custom)
4. Review split calculation
5. Click **"Add Expense"**
6. Expense appears in history

### View Balances:
- **Dashboard**: Quick balance overview
- **Group Details**: Full expense history + balances

---

## 🔑 Important Notes

### Android Setup
For Google Sign-In to work on Android:
1. Get your app's SHA-1 fingerprint:
   ```bash
   cd android
   gradlew signingReport
   ```
2. Add it to Firebase Console → Project Settings → Apps

### iOS Setup (if deploying to iOS)
1. Download GoogleService-Info.plist from Firebase
2. Add it to Xcode project
3. Run: `flutter clean && flutter pub get`

### Emulator Testing
- Android Emulator: Requires Google Play Services
- iOS Simulator: May not support Google Sign-In (use device for testing)

---

## 📝 Test Scenarios

### Scenario 1: Simple 3-way Split
```
Group: Flatmates
Expense: Groceries (₹300)
Members: Alice, Bob, Charlie
Payer: Alice
Split: Equal (₹100 each)

Result:
- Alice: +₹200 (paid ₹300, owes ₹100)
- Bob: -₹100 (owes)
- Charlie: -₹100 (owes)
```

### Scenario 2: Custom Split
```
Group: Flatmates
Expense: Rent (₹15,000)
Members: Alice, Bob, Charlie
Payer: Alice
Split: Custom (Alice ₹5000, Bob ₹5000, Charlie ₹5000)

Result:
- Alice: +₹10,000 (paid ₹15,000, owes ₹5,000)
- Bob: -₹5,000
- Charlie: -₹5,000
```

---

## 🐛 Troubleshooting

### "Google Sign-In Failed"
- ✅ Check Firebase is configured (check lib/firebase_options.dart exists)
- ✅ Check Google Sign-In API is enabled in Firebase Console
- ✅ Android: Check SHA-1 is added to Firebase

### "Firestore permission denied"
- ✅ Make sure Firestore is in test mode (no authentication required initially)
- ✅ Check database is created and active

### "Expense not saving"
- ✅ Check user is logged in
- ✅ Check group has at least one member (current user)
- ✅ Check split total matches expense amount

### "App crashes on startup"
- ✅ Run `flutter clean` and `flutter pub get`
- ✅ Ensure Firebase initialization completes before app loads
- ✅ Check logs: `flutter run` shows detailed error messages

---

## 📊 Data Inspection

### View Firestore Data
```bash
# In Firebase Console → Firestore Database
# Collections visible:
- users/
- groups/
- expenses/
```

### View Logs
```bash
# In Firebase Console → Logging
# Check for errors during sync
```

---

## 🚀 Next Steps After Getting Started

1. **Test the app thoroughly** with multiple users/groups
2. **Implement offline caching** using `shared_preferences`
3. **Add settlement suggestions** (who pays whom)
4. **Build member invite system** via email
5. **Add test data** for development

---

## 💡 Pro Tips

- **Use test accounts**: Create multiple Google accounts to test multi-user scenarios
- **Check real-time sync**: Add expense from one phone, see it update on another
- **Monitor costs**: Watch Firestore read/write counts in Firebase Console
- **Zero costs goal**: All logic is client-side, so costs only grow with users (not computation)

---

## ✅ Verification Checklist

- [ ] Firebase is configured (`firebase_options.dart` exists)
- [ ] Google Sign-In is enabled in Firebase Console
- [ ] Firestore is created and in test mode
- [ ] Android SHA-1 is added (for Android testing)
- [ ] App builds without errors
- [ ] Can login with Google
- [ ] Can create a group
- [ ] Can add an expense
- [ ] Balances update correctly
- [ ] Offline indicators work (when implemented)

---

## 📞 Need Help?

Check these files for implementation details:
- `lib/features/auth/` - Authentication flow
- `lib/features/expense/` - Split logic implementation
- `lib/core/router/` - Navigation structure
- `REAL_FEATURES_COMPLETE.md` - Detailed feature list

**Happy expense splitting!** 🎉
