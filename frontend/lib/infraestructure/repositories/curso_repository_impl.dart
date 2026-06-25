import '../../domain/entities/curso.dart';
import '../../domain/repositories/curso_repository.dart';
import '../datasources/api_datasource.dart';

class CursoRepositoryImpl implements CursoRepository {
  CursoRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;

  @override
  Future<List<Curso>> getCursos() => _datasource.getCursos();

  @override
  Future<List<Curso>> getCursosPorTurno(String turno) async {
    final cursos = await _datasource.getCursos();
    return cursos.where((c) => c.turno == turno).toList();
  }

  @override
  Future<Curso?> getCursoPorId(String id) async {
    final cursos = await _datasource.getCursos();
    try {
      return cursos.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}