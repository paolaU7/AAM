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

  Future<User> updateUser({
    required String id,
    required String firstName,
    required String lastName,
    required UserRole role,
  });

  /// Borrado físico — puede fallar (y lanzar) si el usuario tiene registros
  /// asociados. Usar `toggleActive` para revocar acceso sin perder historial.
  Future<void> deleteUser(String id);
}
