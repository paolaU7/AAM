import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/api_datasource.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;

  @override
  Future<List<User>> getUsers() => _datasource.getUsers();

  @override
  Future<User?> getUserById(String id) async {
    final users = await getUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CreatedUser> createUser({
    required String firstName,
    required String lastName,
    required UserRole role,
  }) =>
      _datasource.crearUsuario(firstName: firstName, lastName: lastName, role: role);

  @override
  Future<User> toggleActive(String userId) => _datasource.toggleUserActive(userId);

  @override
  Future<String> resetPassword(String userId) => _datasource.resetUserPassword(userId);
}
