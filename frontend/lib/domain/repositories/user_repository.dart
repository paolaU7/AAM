import '../entities/user.dart';

abstract class UserRepository {
  Future<List<User>> getUsers();
  Future<User?> getUserById(String id);
  Future<User> createUser(User user);
  Future<User> toggleActive(String userId);
  Future<void> resetPassword(String userId);
}