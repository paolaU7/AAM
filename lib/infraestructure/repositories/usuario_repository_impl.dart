import '../../domain/entities/usuario.dart';
import '../../domain/repositories/usuario_repository.dart';
import '../datasources/mock_datasource.dart';

class UsuarioRepositoryImpl implements UsuarioRepository {
  UsuarioRepositoryImpl(this._datasource);
  final MockDatasource _datasource;

  // Estado local mutable para el mock (simula base de datos en memoria)
  late List<Usuario> _cache = _datasource.getUsuarios();

  @override
  Future<List<Usuario>> getUsuarios() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_cache);
  }

  @override
  Future<Usuario?> getUsuarioPorId(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _cache.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Usuario> crearUsuario(Usuario usuario) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final nuevo = usuario.copyWith(
      id: 'u${(_cache.length + 1).toString().padLeft(3, '0')}',
    );
    _cache = [..._cache, nuevo];
    return nuevo;
  }

  @override
  Future<Usuario> toggleActivo(String usuarioId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _cache = _cache.map((u) {
      if (u.id == usuarioId) return u.copyWith(activo: !u.activo);
      return u;
    }).toList();
    return _cache.firstWhere((u) => u.id == usuarioId);
  }

  @override
  Future<void> resetearClave(String usuarioId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // En mock: no hace nada real. Con API: POST /usuarios/{id}/reset-clave
  }
}
