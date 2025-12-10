# Google Sign-In Troubleshooting Guide

## ❌ Error: "Unable to Sign In"

### Most Common Causes:

1. **SHA-1 Fingerprint Not Added (Android)**
2. **Google Sign-In Not Enabled in Firebase**
3. **Firebase Not Properly Configured**
4. **OAuth Client ID Issues**

---

## 🔧 Fix Step-by-Step

### Step 1: Get Your SHA-1 Fingerprint

```bash
# For debug builds (development)
cd android
./gradlew signingReport

# Or on Windows:
gradlew.bat signingReport
```

Look for the **SHA-1** under `Variant: debug`, something like:
```
SHA1: A1:B2:C3:D4:E5:F6:...
```

**Copy this SHA-1!**

---

### Step 2: Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project **"contri"**
3. Click **⚙️ Project Settings** (top left gear icon)
4. Scroll down to **Your apps** section
5. Find your Android app (com.example.contri)
6. Click **"Add fingerprint"**
7. **Paste your SHA-1**
8. Click **Save**

---

### Step 3: Download Updated google-services.json

After adding SHA-1:

1. In Firebase Console → Project Settings
2. Scroll to your Android app
3. Click **"Download google-services.json"**
4. **Replace** the file in your project:
   ```
   android/app/google-services.json
   ```

---

### Step 4: Enable Google Sign-In in Firebase

1. In Firebase Console, go to **Authentication**
2. Click **"Sign-in method"** tab
3. Find **Google** provider
4. Click **Edit** (pencil icon)
5. **Enable** the toggle
6. Set **Project support email** (your email)
7. Click **Save**

---

### Step 5: Verify OAuth Configuration

1. In Firebase Console → Authentication → Sign-in method → Google
2. Expand **"Web SDK configuration"**
3. You should see **Web client ID**
4. Copy this ID

Then check if it matches in your app:
```bash
# Check if Web Client ID is in google-services.json
cat android/app/google-services.json | grep client_id
```

---

### Step 6: Clean and Rebuild

```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# Rebuild and run
flutter run
```

---

## 🔍 Check the Logs

When you try to sign in, look for debug prints:

```
✅ Good signs:
🔐 Starting Google Sign-In...
✅ Google user obtained: user@example.com
🔐 Getting authorization headers...
✅ Auth header obtained
✅ ID token extracted
🔐 Signing in to Firebase...
✅ Firebase user: user@example.com
💾 Saving user to Firestore...
🎉 Sign-in complete!

❌ Bad signs:
❌ Google Sign-In cancelled by user
❌ Authorization header is null
❌ Failed to get auth token from Google
❌ Sign-in error: ...
```

---

## 🐛 Common Error Messages

### "PlatformException (sign_in_failed, ...)"
**Solution**: SHA-1 not added or wrong SHA-1
→ Re-check Step 1-2

### "ApiException: 10"
**Solution**: OAuth client ID mismatch
→ Re-download google-services.json (Step 3)

### "DEVELOPER_ERROR"
**Solution**: SHA-1 for debug keystore not added
→ Add SHA-1 for debug build (Step 1-2)

### "Google Sign-In was cancelled"
**Solution**: User cancelled or popup didn't show
→ Check if Google Play Services is installed on emulator

---

## 📱 Android Emulator Requirements

For Google Sign-In to work on emulator:

1. **Use an emulator with Google Play Services**
   - In Android Studio AVD Manager
   - Select an image with "Play Store" icon
   - NOT the basic AOSP images

2. **Sign in to Google Play Store**
   - Open Play Store app in emulator
   - Sign in with a Google account

---

## ✅ Quick Verification Checklist

- [ ] SHA-1 fingerprint added to Firebase Console
- [ ] google-services.json downloaded and placed correctly
- [ ] Google Sign-In enabled in Firebase Authentication
- [ ] Project support email set in Firebase
- [ ] Using emulator with Google Play Services
- [ ] Internet connection active
- [ ] Firebase initialized in main.dart

---

## 🎯 Test Command

Run with verbose logging:

```bash
flutter run -v
```

Look for these specific messages:
- `Resolving dependencies...` (should succeed)
- `google_sign_in: ...` (plugin loaded)
- `firebase_auth: ...` (auth loaded)

---

## 💡 Alternative: Test with Physical Device

If emulator issues persist:

1. Enable USB debugging on Android phone
2. Connect via USB
3. Run: `flutter devices`
4. Run: `flutter run`

Physical devices have fewer Google Play Services issues.

---

## 🔄 Still Not Working?

### Last Resort Steps:

1. **Delete and recreate Firebase project**
   ```bash
   flutterfire configure --force
   ```

2. **Check Firebase initialization**
   ```dart
   // In main.dart, add error handling:
   try {
     await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
     debugPrint('✅ Firebase initialized');
   } catch (e) {
     debugPrint('❌ Firebase init failed: $e');
   }
   ```

3. **Verify internet connection**
   ```bash
   # Test connectivity
   adb shell ping google.com
   ```

4. **Check Firebase Console → Usage**
   - See if any authentication attempts are logged
   - Check for error counts

---

## 📞 Get Help

If still stuck, collect this info:

1. **SHA-1 from your machine**: `gradlew signingReport`
2. **SHA-1 in Firebase Console**: (screenshot)
3. **Error logs**: Copy the full error from terminal
4. **Firebase project ID**: From Firebase Console
5. **google-services.json**: Check if `client_id` exists

Then debug with these logs! 🚀
