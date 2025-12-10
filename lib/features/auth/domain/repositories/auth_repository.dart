import '../entities/app_user.dart';

/// Domain Repository Interface for Authentication
abstract class AuthRepository {
  /// Sign in with Google
  Future<AppUser> signInWithGoogle();

  /// Sign out
  Future<void> signOut();

  /// Get current user stream
  Stream<AppUser?> get authStateChanges;

  /// Get current user
  Future<AppUser?> getCurrentUser();

  /// Get user by email
  Future<AppUser?> getUserByEmail(String email);

  /// Get multiple users by their IDs (returns List, not Map)
  Future<List<AppUser>> getUsersByIds(List<String> userIds);
}
