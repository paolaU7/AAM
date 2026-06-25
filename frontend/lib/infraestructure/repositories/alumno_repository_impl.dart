import '../../domain/entities/alumno.dart';
import '../../domain/repositories/alumno_repository.dart';
import '../datasources/api_datasource.dart';

class AlumnoRepositoryImpl implements AlumnoRepository {
  AlumnoRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;

  @override
  Future<List<Alumno>> getAlumnos() => _datasource.getAlumnos();

  @override
  Future<List<Alumno>> getAlumnosPorCurso(String cursoId) async {
    final alumnos = await _datasource.getAlumnos();
    return alumnos.where((a) => a.cursoId == cursoId).toList();
  }

  @override
  Future<Alumno?> getAlumnoPorId(String id) async {
    final alumnos = await _datasource.getAlumnos();
    try {
      return alumnos.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Alumno?> getAlumnoPorDni(String dni) async {
    final alumnos = await _datasource.getAlumnos();
    try {
      return alumnos.firstWhere((a) => a.dni == dni);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Alumno> crearAlumno(Alumno alumno) async => alumno;

  @override
  Future<Alumno> actualizarAlumno(Alumno alumno) async => alumno;
}