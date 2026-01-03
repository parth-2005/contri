/// Firestore Collection Names
class FirebaseConstants {
  // Collection Names
  static const String usersCollection = 'users';
  static const String groupsCollection = 'groups';
  static const String expensesCollection = 'expenses';
  
  // Field Names - Users
  static const String userNameField = 'name';
  static const String userEmailField = 'email';
  static const String userPhotoUrlField = 'photoUrl';
  static const String userTotalOwedField = 'total_owed';
  
  // Field Names - Groups
  static const String groupNameField = 'name';
  static const String groupMembersField = 'members';
  static const String groupBalancesField = 'balances';
  static const String groupDefaultSharesField = 'defaultShares';
  static const String groupCreatedAtField = 'createdAt';
  static const String groupTypeField = 'type'; // trip, home, couple, other
  static const String groupSettingsField = 'settings'; // Map<String, dynamic> for feature toggles
  static const String groupTotalExpenseField = 'totalExpense'; // Cached sum of all expenses
  
  // Field Names - Expenses
  static const String expenseGroupIdField = 'groupId';
  static const String expenseDescriptionField = 'description';
  static const String expenseAmountField = 'amount';
  static const String expensePaidByField = 'paidBy';
  static const String expenseSplitMapField = 'splitMap';
  static const String expenseSplitTypeField = 'splitType';
  static const String expenseFamilySharesField = 'familyShares';
  static const String expenseDateField = 'date';
  static const String expenseCreatedAtField = 'createdAt';
  static const String expenseCategoryField = 'category';
  static const String expenseTypeField = 'type'; // personal, family, group
  static const String expenseMemberIdField = 'memberId'; // For tracking specific family members
}
