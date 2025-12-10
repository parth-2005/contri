import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/group.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Data Model for Group (Firestore)
class GroupModel {
  final String id;
  final String name;
  final List<String> members;
  final Map<String, double> balances;
  final DateTime? createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.members,
    required this.balances,
    this.createdAt,
  });

  /// Convert to Domain Entity
  Group toEntity() {
    return Group(
      id: id,
      name: name,
      members: members,
      balances: balances,
      createdAt: createdAt,
    );
  }

  /// Convert from Domain Entity
  factory GroupModel.fromEntity(Group group) {
    return GroupModel(
      id: group.id,
      name: group.name,
      members: group.members,
      balances: group.balances,
      createdAt: group.createdAt,
    );
  }

  /// Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.groupNameField: name,
      FirebaseConstants.groupMembersField: members,
      FirebaseConstants.groupBalancesField: balances,
      FirebaseConstants.groupCreatedAtField: FieldValue.serverTimestamp(),
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
      createdAt: data[FirebaseConstants.groupCreatedAtField] != null
          ? (data[FirebaseConstants.groupCreatedAtField] as Timestamp).toDate()
          : null,
    );
  }
}
