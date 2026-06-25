import '../entities/usuario.dart';

abstract class UsuarioRepository {
  Future<List<Usuario>> getUsuarios();
  Future<Usuario?> getUsuarioPorId(String id);
  Future<Usuario> crearUsuario(Usuario usuario);
  Future<Usuario> toggleActivo(String usuarioId);
  Future<void> resetearClave(String usuarioId);
}
