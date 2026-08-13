import '../entities/user.dart';

abstract class UserRepository {
  Future<List<User>> getUsers();
  Future<User?> getUserById(String id);

  Future<CreatedUser> createUser({
    required String firstName,
    required String lastName,
    required UserRole role,
  });

  Future<User> toggleActive(String userId);

  /// Returns the new temporary password (shown once).
  Future<String> resetPassword(String userId);
}
