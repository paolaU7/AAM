import '../entities/alumno.dart';

/// Puerto de salida — el dominio define QUÉ necesita,
/// sin saber nada de FastAPI ni PostgreSQL.
abstract class AlumnoRepository {
  Future<List<Alumno>> getAlumnos();
  Future<List<Alumno>> getAlumnosPorCurso(String cursoId);
  Future<Alumno?> getAlumnoPorId(String id);
  Future<Alumno?> getAlumnoPorDni(String dni);
  Future<Alumno> crearAlumno(Alumno alumno);
  Future<Alumno> actualizarAlumno(Alumno alumno);
}
