import '../entities/user.dart';
import '../repositories/user_repository.dart';

class CreateUser {
  const CreateUser(this.repository);
  final UserRepository repository;

  Future<CreatedUser> call({
    required String firstName,
    required String lastName,
    required UserRole role,
  }) async {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty || l.isEmpty) {
      throw const CreateUserException('Completá nombre y apellido.');
    }

    return repository.createUser(firstName: f, lastName: l, role: role);
  }
}

class CreateUserException implements Exception {
  const CreateUserException(this.message);
  final String message;

  @override
  String toString() => message;
}
