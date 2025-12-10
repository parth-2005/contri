# Fix: Firestore Composite Index Required

## ❌ Error Message
```
Listen for Query(target=Query(groups where members array-contains... order by -createdAt) 
failed: Status{code=FAILED_PRECONDITION, description=The query requires an index.
```

## 🔧 Fix: Create the Composite Index

### Method 1: Quick Fix via Error Message Link

1. **Look at your app logs** - find the error message
2. **Copy the link** from the error (starts with `https://console.firebase.google.com/v1/r/project/...`)
3. **Open the link** in your browser
4. **Click "Create composite index"**
5. **Wait 2-3 minutes** for index to build
6. **Run your app again** - error should be gone! 🎉

---

### Method 2: Manual Creation in Firebase Console

If the automatic link doesn't work:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project **"contri"**
3. Go to **Firestore Database** → **Indexes** (tab at top)
4. Click **Create Index** button
5. Fill in:
   - **Collection ID**: `groups`
   - **Field 1**: 
     - Name: `members`
     - Type: `Ascending` (or `Arrays`)
   - **Field 2**: 
     - Name: `createdAt`
     - Type: `Descending`

6. Click **Create Index**
7. Wait for status to change from `Enabling` → `Enabled` (2-3 minutes)

---

## 🎯 Why This Happens

Your app queries groups like this:
```dart
// This query needs a composite index:
.where(members, arrayContains: userId)
.orderBy(createdAt, descending: true)
```

Firestore requires composite indexes for queries that combine:
- ✓ WHERE clause (arrayContains)
- ✓ ORDER BY clause

---

## ✅ After Creating Index

The dashboard will:
1. ✅ Load your groups instantly
2. ✅ Sort by newest first
3. ✅ No more "FAILED_PRECONDITION" errors

---

## 🚀 Quick Test

After index is created and enabled:

```powershell
flutter run
```

Click on a group name on the dashboard - it should load without errors!

---

## 💡 Note

This is a **one-time setup** - you only need to create the index once. It will work forever after that (unless you delete it accidentally).

Firestore free tier includes **automatic index creation** for most queries, but compound queries with WHERE + ORDER BY sometimes need manual setup.
