/// Domain entity: System user (preceptor or direction)
class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String username; // display alias, derived from the name (abc.xyz)
  final String email;
  final UserRole role;
  final bool isActive;

  String get fullName => '$lastName, $firstName';

  /// Generates the display username from the full name.
  /// Ex: "Rodríguez, María" → "rod.mar"
  static String generateUsername(String lastName, String firstName) {
    String clean(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z]'), '');

    final l = clean(lastName);
    final f = clean(firstName);
    final lastPart = l.length >= 3 ? l.substring(0, 3) : l;
    final firstPart = f.length >= 3 ? f.substring(0, 3) : f;
    return '$lastPart.$firstPart';
  }

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    UserRole? role,
    bool? isActive,
  }) {
    return User(
      id:        id        ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName:  lastName  ?? this.lastName,
      username:  username  ?? this.username,
      email:     email     ?? this.email,
      role:      role      ?? this.role,
      isActive:  isActive  ?? this.isActive,
    );
  }
}

/// Result of creating a user: the temporary password is only ever exposed
/// this once — the backend never lets you read it back afterward.
class CreatedUser {
  const CreatedUser({required this.user, required this.temporaryPassword});
  final User user;
  final String temporaryPassword;
}

enum UserRole { principal, preceptor }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.principal:  return 'DIRECCIÓN';
      case UserRole.preceptor:  return 'PRECEPTOR';
    }
  }
}
