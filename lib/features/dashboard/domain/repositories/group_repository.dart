import '../entities/group.dart';

/// Domain Repository Interface for Group Operations
abstract class GroupRepository {
  /// Create a new group
  Future<void> createGroup({
    required String name,
    required List<String> members,
  });

  /// Get all groups where user is a member
  Stream<List<Group>> getGroupsForUser(String userId);

  /// Get a specific group by ID
  Future<Group?> getGroupById(String groupId);

  /// Update group name
  Future<void> updateGroupName(String groupId, String newName);

  /// Add member to group
  Future<void> addMemberToGroup(String groupId, String userId);

  /// Remove member from group
  Future<void> removeMemberFromGroup(String groupId, String userId);

  /// Join an existing group by ID
  Future<void> joinGroup(String groupId, String userId);
}
