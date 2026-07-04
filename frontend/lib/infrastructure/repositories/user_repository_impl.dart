import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/mock_datasource.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._datasource);
  final MockDatasource _datasource;

  // Local mutable state for the mock (simulates an in-memory database)
  late List<User> _cache = _datasource.getUsuarios();

  @override
  Future<List<User>> getUsers() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_cache);
  }

  @override
  Future<User?> getUserById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _cache.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<User> createUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final newUser = user.copyWith(
      id: 'u${(_cache.length + 1).toString().padLeft(3, '0')}',
    );
    _cache = [..._cache, newUser];
    return newUser;
  }

  @override
  Future<User> toggleActive(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _cache = _cache.map((u) {
      if (u.id == userId) return u.copyWith(isActive: !u.isActive);
      return u;
    }).toList();
    return _cache.firstWhere((u) => u.id == userId);
  }

  @override
  Future<void> resetPassword(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock: does nothing real. With API: POST /users/{id}/reset-password
  }
}