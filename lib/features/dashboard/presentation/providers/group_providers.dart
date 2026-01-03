import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/group.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Provider for GroupRepository
final groupRepositoryProvider = Provider((ref) {
  return GroupRepositoryImpl();
});

/// Provider for user's groups
final userGroupsProvider = StreamProvider<List<Group>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value([]);
      }
      final repository = ref.watch(groupRepositoryProvider);
      return repository.getGroupsForUser(user.id);
    },
    loading: () => Stream.value([]),
    error: (_, err) => Stream.value([]),
  );
});

/// Live provider for a specific group by ID
final groupByIdProvider = StreamProvider.family<Group?, String>((ref, groupId) {
  final repository = ref.watch(groupRepositoryProvider);
  return repository.watchGroupById(groupId);
});
