import '../entities/user.dart';
import '../repositories/user_repository.dart';

class CreateUser {
  const CreateUser(this.repository);
  final UserRepository repository;

  Future<User> call({
    required String firstName,
    required String lastName,
    required UserRole role,
    String? shift,
  }) async {
    // Domain validation: preceptor requires an assigned shift
    if (role == UserRole.preceptor && (shift == null || shift.isEmpty)) {
      throw const CreateUserException('A preceptor must have an assigned shift.');
    }

    final username = User.generateUsername(lastName, firstName);

    final user = User(
      id:        '',   // ULID assigned by the backend
      firstName: firstName,
      lastName:  lastName,
      username:  username,
      role:      role,
      shift:     shift,
      isActive:  true,
    );

    return repository.createUser(user);
  }
}

class CreateUserException implements Exception {
  const CreateUserException(this.message);
  final String message;

  @override
  String toString() => message;
}