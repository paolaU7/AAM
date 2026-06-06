import '../entities/curso.dart';

abstract class CursoRepository {
  Future<List<Curso>> getCursos();
  Future<List<Curso>> getCursosPorTurno(String turno);
  Future<Curso?> getCursoPorId(String id);
}
