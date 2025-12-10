import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';
import '../models/group_model.dart';
import '../../../../core/constants/firebase_constants.dart';

/// Implementation of GroupRepository
class GroupRepositoryImpl implements GroupRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  GroupRepositoryImpl({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  @override
  Future<void> createGroup({
    required String name,
    required List<String> members,
  }) async {
    final groupId = _uuid.v4();

    // Initialize balances map with all members having 0 balance
    final Map<String, double> balances = {};
    for (final memberId in members) {
      balances[memberId] = 0.0;
    }

    final group = GroupModel(
      id: groupId,
      name: name,
      members: members,
      balances: balances,
    );

    await _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .set(group.toFirestore());
  }

  @override
  Stream<List<Group>> getGroupsForUser(String userId) {
    return _firestore
        .collection(FirebaseConstants.groupsCollection)
        .where(FirebaseConstants.groupMembersField, arrayContains: userId)
        .orderBy(FirebaseConstants.groupCreatedAtField, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Future<Group?> getGroupById(String groupId) async {
    final doc = await _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .get();

    if (!doc.exists) return null;
    return GroupModel.fromFirestore(doc).toEntity();
  }

  @override
  Future<void> updateGroupName(String groupId, String newName) async {
    await _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .update({FirebaseConstants.groupNameField: newName});
  }

  @override
  Future<void> addMemberToGroup(String groupId, String userId) async {
    await _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .update({
      FirebaseConstants.groupMembersField: FieldValue.arrayUnion([userId]),
      '${FirebaseConstants.groupBalancesField}.$userId': 0.0,
    });
  }

  @override
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    final batch = _firestore.batch();
    final groupRef = _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId);

    batch.update(groupRef, {
      FirebaseConstants.groupMembersField: FieldValue.arrayRemove([userId]),
    });

    // Note: We don't remove the balance entry to maintain historical data
    // It will just be ignored if the user is not in members list

    await batch.commit();
  }

  @override
  Future<void> joinGroup(String groupId, String userId) async {
    await _firestore
        .collection(FirebaseConstants.groupsCollection)
        .doc(groupId)
        .update({
      FirebaseConstants.groupMembersField: FieldValue.arrayUnion([userId]),
      '${FirebaseConstants.groupBalancesField}.$userId': 0.0,
    });
  }
}
