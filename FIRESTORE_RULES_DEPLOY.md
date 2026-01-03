# Firestore Security Rules Deployment Guide

## 🚨 IMPORTANT: Deploy These Rules IMMEDIATELY

The Firestore Security Rules in `firestore.rules` **MUST** be deployed to protect against the critical privacy vulnerability discovered in the security audit.

---

## Quick Deploy (Recommended)

```bash
# 1. Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# 2. Login to Firebase
firebase login

# 3. Initialize Firebase in your project (if not already done)
firebase init firestore

# 4. Deploy ONLY the security rules
firebase deploy --only firestore:rules
```

---

## What These Rules Protect Against

### ❌ BEFORE (Vulnerable)
- Any authenticated user could read any group's data with just the `groupId`
- Users could query expenses from groups they don't belong to
- No server-side authorization checks

### ✅ AFTER (Secure)
- Only group members can read group data
- Only group members can read group expenses
- Personal expenses are isolated to their owners
- All operations validated server-side

---

## Testing the Rules

### 1. Firebase Console Rules Playground
1. Go to Firebase Console → Firestore Database → Rules tab
2. Click "Rules Playground"
3. Test these scenarios:

#### Test Case 1: Non-member tries to read group
```javascript
// Simulate as user: user_a@example.com
// Location: /groups/group123
// Operation: get

// Expected: DENIED (if user_a is not in group123.members)
```

#### Test Case 2: Member reads own group
```javascript
// Simulate as user: user_a@example.com  
// Location: /groups/group123
// Operation: get

// Expected: ALLOWED (if user_a is in group123.members)
```

#### Test Case 3: User reads personal expense
```javascript
// Simulate as user: user_a@example.com
// Location: /expenses/expense123
// Operation: get

// Expected: ALLOWED (if expense123.paidBy == user_a AND groupId == null)
```

### 2. App Testing
After deploying, test these flows in your app:

#### ✅ Should Work:
- [ ] User A can see their own groups
- [ ] User A can view expenses in their groups
- [ ] User A can add expenses to their groups
- [ ] User A can see their personal expenses in Analytics

#### ❌ Should Fail:
- [ ] User A cannot access User B's groups (even with groupId)
- [ ] User A cannot see expenses from groups they're not in
- [ ] User A cannot see other users' personal expenses

---

## Rule Breakdown

### Groups Collection
```javascript
match /groups/{groupId} {
  // Only members can read
  allow read: if isGroupMember(groupId);
  
  // Only members can update/delete
  allow update, delete: if isGroupMember(groupId);
}
```

**Impact:** 
- `watchGroupById()` will return permission denied for non-members
- `getGroupsForUser()` already uses `arrayContains` so it's safe

### Expenses Collection  
```javascript
match /expenses/{expenseId} {
  // Personal expenses: only owner can access
  allow read: if resource.data.groupId == null && 
                 resource.data.paidBy == request.auth.uid;
  
  // Group expenses: only group members can access
  allow read: if resource.data.groupId != null && 
                 isGroupMember(resource.data.groupId);
}
```

**Impact:**
- `getExpensesForGroup()` will only return expenses if user is a member
- `getFilteredExpenses()` will automatically filter out unauthorized expenses
- Personal expenses in Analytics remain isolated

---

## Rollback Plan

If something breaks after deployment:

### Option 1: Revert to Open Rules (INSECURE - Temporary Only)
```bash
# Create a temporary rules file
cat > firestore.rules.emergency << EOF
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
EOF

# Deploy emergency rules
firebase deploy --only firestore:rules --force
```

### Option 2: Revert to Previous Version
```bash
# Check deployment history
firebase firestore:releases:list

# Rollback to previous release
firebase firestore:releases:rollback <RELEASE_ID>
```

---

## Monitoring After Deployment

### 1. Check Firebase Console
- Monitor "Requests" tab for sudden drops (indicates blocked requests)
- Check for error spikes in "Usage" tab

### 2. Check App Logs
Look for Firestore permission errors:
```
[cloud_firestore/permission-denied] Missing or insufficient permissions
```

**If you see these:**
- Verify the user IS a member of the group
- Check if `effectiveGroup.members` contains the user's UID
- Ensure Firestore rules match the `firestore.rules` file

---

## Common Issues & Solutions

### Issue: Users can't see their own groups
**Cause:** UID mismatch between Auth and Firestore  
**Fix:** 
```dart
// Ensure user ID consistency
print('Auth UID: ${FirebaseAuth.instance.currentUser?.uid}');
print('Group members: ${group.members}');
```

### Issue: "Missing permissions" error on valid operations
**Cause:** Rules not deployed or cached  
**Fix:**
```bash
# Force deploy
firebase deploy --only firestore:rules --force

# Clear app data to refresh cache
# OR wait 10 minutes for rules to propagate
```

### Issue: Join group flow breaks
**Cause:** `joinGroup()` might fail if rules are too strict  
**Fix:** Already handled - rules allow `arrayUnion` operations on members field

---

## Final Checklist

Before considering this deployment complete:

- [ ] Rules deployed: `firebase deploy --only firestore:rules`
- [ ] Tested in Rules Playground (Firebase Console)
- [ ] Tested with real users in app
- [ ] Verified existing functionality still works
- [ ] No permission errors in Firebase Console
- [ ] Documented rollback procedure for team

---

## Need Help?

If deployment fails or users report issues:

1. Check Firebase Console → Firestore → Rules tab for syntax errors
2. Review the [Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
3. Use Rules Playground to debug specific queries
4. Temporarily rollback if critical functionality is broken

**Remember:** These rules are CRITICAL for user privacy. Do not delay deployment!
