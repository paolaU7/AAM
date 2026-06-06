import '../entities/usuario.dart';
import '../repositories/usuario_repository.dart';

class CrearUsuario {
  const CrearUsuario(this.repository);
  final UsuarioRepository repository;

  Future<Usuario> call({
    required String nombre,
    required String apellido,
    required RolUsuario rol,
    String? turno,
  }) async {
    // Validación de dominio: preceptor requiere turno
    if (rol == RolUsuario.preceptor && (turno == null || turno.isEmpty)) {
      throw const CrearUsuarioException('El preceptor debe tener un turno asignado.');
    }

    final username = Usuario.generarUsername(apellido, nombre);

    final usuario = Usuario(
      id:       '',   // el backend asigna el ULID
      nombre:   nombre,
      apellido: apellido,
      username: username,
      rol:      rol,
      turno:    turno,
      activo:   true,
    );

    return repository.crearUsuario(usuario);
  }
}

class CrearUsuarioException implements Exception {
  const CrearUsuarioException(this.message);
  final String message;

  @override
  String toString() => message;
}
