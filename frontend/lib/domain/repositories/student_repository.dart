import '../entities/student.dart';

/// Puerto de salida — el dominio define QUÉ necesita,
/// sin saber nada de FastAPI ni PostgreSQL.
abstract class StudentRepository {
  Future<List<Student>> getAlumnos();
  Future<List<Student>> getAlumnosPorCurso(String cursoId);
  Future<Student?> getAlumnoPorId(String id);
  Future<Student?> getAlumnoPorDni(String dni);
  Future<Student> crearAlumno(Student alumno);
  Future<Student> actualizarAlumno(Student alumno);
}
