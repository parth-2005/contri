import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_user.dart';
import '../../../dashboard/presentation/providers/group_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Provider to get user profiles for a list of user IDs
/// Returns a Map for easy lookup: { 'user_id': AppUserObject }
final memberProfilesProvider =
    FutureProvider.family<Map<String, AppUser>, List<String>>((ref, userIds) async {
  final authRepository = ref.watch(authRepositoryProvider);
  
  if (userIds.isEmpty) {
    return {};
  }
  
  // Fetch List from Repository
  final List<AppUser> usersList = await authRepository.getUsersByIds(userIds);
  
  // Convert List -> Map for easy lookup by user ID
  final Map<String, AppUser> usersMap = {
    for (var user in usersList) user.id: user
  };
  
  return usersMap;
});

/// Provider to get user profiles for a specific group
final groupMembersProvider =
    FutureProvider.family<Map<String, AppUser>, String>((ref, groupId) async {
  final groupsAsync = ref.watch(userGroupsProvider);
  
  // Use when to handle AsyncValue properly
  if (groupsAsync.isLoading) {
    throw Exception('Loading groups...');
  }
  
  if (groupsAsync.hasError) {
    throw Exception('Failed to load group: ${groupsAsync.error}');
  }
  
  final groups = groupsAsync.value ?? [];
  final group = groups.firstWhere(
    (g) => g.id == groupId,
    orElse: () => throw Exception('Group not found'),
  );
  
  final authRepository = ref.watch(authRepositoryProvider);
  final List<AppUser> usersList = await authRepository.getUsersByIds(group.members);
  
  // Convert List -> Map
  final Map<String, AppUser> usersMap = {
    for (var user in usersList) user.id: user
  };
  
  return usersMap;
});
