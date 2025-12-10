import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_user.dart';
import '../../data/repositories/auth_repository_impl.dart';

/// Provider for AuthRepository
final authRepositoryProvider = Provider((ref) {
  return AuthRepositoryImpl();
});

/// Provider for auth state changes
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

/// Provider for current user
final currentUserProvider = FutureProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.getCurrentUser();
});
