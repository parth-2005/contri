import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/group.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Data Model for Group (Firestore)
class GroupModel {
  final String id;
  final String name;
  final List<String> members;
  final Map<String, double> balances;
  final Map<String, double> defaultShares;
  final DateTime? createdAt;
  final GroupType type;
  final Map<String, dynamic> settings;
  final double totalExpense;

  GroupModel({
    required this.id,
    required this.name,
    required this.members,
    required this.balances,
    this.defaultShares = const {},
    this.createdAt,
    this.type = GroupType.other,
    this.settings = const {},
    this.totalExpense = 0.0,
  });

  /// Convert to Domain Entity
  Group toEntity() {
    return Group(
      id: id,
      name: name,
      members: members,
      balances: balances,
      defaultShares: defaultShares,
      createdAt: createdAt,
      type: type,
      settings: settings,
      totalExpense: totalExpense,
    );
  }

  /// Convert from Domain Entity
  factory GroupModel.fromEntity(Group group) {
    return GroupModel(
      id: group.id,
      name: group.name,
      members: group.members,
      balances: group.balances,
      defaultShares: group.defaultShares,
      createdAt: group.createdAt,
      type: group.type,
      settings: group.settings,
      totalExpense: group.totalExpense,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.groupNameField: name,
      FirebaseConstants.groupMembersField: members,
      FirebaseConstants.groupBalancesField: balances,
      FirebaseConstants.groupDefaultSharesField: defaultShares,
      FirebaseConstants.groupCreatedAtField: FieldValue.serverTimestamp(),
      FirebaseConstants.groupTypeField: type.toShortString(),
      FirebaseConstants.groupSettingsField: settings,
      FirebaseConstants.groupTotalExpenseField: totalExpense,
    };
  }

  /// Convert from Firestore DocumentSnapshot
  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: data[FirebaseConstants.groupNameField] as String,
      members: List<String>.from(data[FirebaseConstants.groupMembersField] ?? []),
      balances: Map<String, double>.from(
        (data[FirebaseConstants.groupBalancesField] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
      ),
      defaultShares: Map<String, double>.from(
        (data[FirebaseConstants.groupDefaultSharesField] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
      ),
      createdAt: data[FirebaseConstants.groupCreatedAtField] != null
          ? (data[FirebaseConstants.groupCreatedAtField] as Timestamp).toDate()
          : null,
      type: data[FirebaseConstants.groupTypeField] != null
          ? GroupTypeExtension.fromString(data[FirebaseConstants.groupTypeField] as String)
          : GroupType.other,
      settings: Map<String, dynamic>.from(
        data[FirebaseConstants.groupSettingsField] as Map<String, dynamic>? ?? {},
      ),
      totalExpense: data[FirebaseConstants.groupTotalExpenseField] != null
          ? (data[FirebaseConstants.groupTotalExpenseField] as num).toDouble()
          : 0.0,
    );
  }
}
