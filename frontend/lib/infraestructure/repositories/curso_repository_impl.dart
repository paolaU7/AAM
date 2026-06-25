import '../../domain/entities/curso.dart';
import '../../domain/repositories/curso_repository.dart';
import '../datasources/mock_datasource.dart';

class CursoRepositoryImpl implements CursoRepository {
  CursoRepositoryImpl(this._datasource);
  final MockDatasource _datasource;

  @override
  Future<List<Curso>> getCursos() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _datasource.getCursos();
  }

  @override
  Future<List<Curso>> getCursosPorTurno(String turno) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _datasource.getCursos().where((c) => c.turno == turno).toList();
  }

  @override
  Future<Curso?> getCursoPorId(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _datasource.getCursos().firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
