import '../../domain/entities/alumno.dart';
import '../../domain/repositories/alumno_repository.dart';
import '../datasources/mock_datasource.dart';

/// Implementación concreta del AlumnoRepository.
/// Hoy usa MockDatasource. Cuando el backend esté listo,
/// se reemplaza por ApiDatasource sin tocar el dominio ni la UI.
class AlumnoRepositoryImpl implements AlumnoRepository {
  AlumnoRepositoryImpl(this._datasource);
  final MockDatasource _datasource;

  @override
  Future<List<Alumno>> getAlumnos() async {
    await Future.delayed(const Duration(milliseconds: 300)); // simula latencia
    return _datasource.getAlumnos();
  }

  @override
  Future<List<Alumno>> getAlumnosPorCurso(String cursoId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _datasource.getAlumnos().where((a) => a.cursoId == cursoId).toList();
  }

  @override
  Future<Alumno?> getAlumnoPorId(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _datasource.getAlumnos().firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Alumno?> getAlumnoPorDni(String dni) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _datasource.getAlumnos().firstWhere((a) => a.dni == dni);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Alumno> crearAlumno(Alumno alumno) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // En mock: retorna el mismo alumno con un id simulado
    return alumno.copyWith(id: 'mock_${DateTime.now().millisecondsSinceEpoch}');
  }

  @override
  Future<Alumno> actualizarAlumno(Alumno alumno) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return alumno;
  }
}
