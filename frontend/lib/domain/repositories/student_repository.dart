import '../entities/student.dart';
import '../entities/course.dart';
import '../entities/workshop_group.dart';

/// Puerto de salida — el dominio define QUÉ necesita,
/// sin saber nada de FastAPI ni PostgreSQL.
abstract class StudentRepository {
  /// Por default trae solo alumnos activos.
  Future<List<Student>> getAlumnos({bool incluirInactivos = false});
  Future<List<Student>> getAlumnosPorCurso(String cursoId);
  Future<Student?> getAlumnoPorId(String id);
  Future<Student?> getAlumnoPorDni(String dni);

  // ── Alta manual en cascada (año lectivo → año de cursada → división) ───────
  // `courses` no tiene tablas catálogo propias: año lectivo/año de cursada/
  // división son 3 columnas numéricas directas con UNIQUE compuesto, así que
  // los selectores se arman a partir de los cursos ya existentes.

  /// Cursos existentes, usados para derivar las opciones de los 3 selectores
  /// en cascada y resolver el `course_id` real una vez elegidos los tres.
  Future<List<Course>> getCourses();

  /// Grupos de taller de UN curso puntual — son una subdivisión interna del
  /// curso (no se comparten entre cursos), por eso se piden recién una vez
  /// resuelto el `course_id`.
  Future<List<WorkshopGroup>> getWorkshopGroupsByCourse(String courseId);

  /// `workshopGroupId`, si se da, debe pertenecer a `courseId` — lo valida
  /// el backend.
  Future<Student> crearAlumno({
    required String firstName,
    required String lastName,
    required String nationalId,
    required String courseId,
    String? workshopGroupId,
  });

  Future<Student> actualizarAlumno(Student alumno);

  /// Baja/alta lógica — no borra al alumno del sistema.
  Future<Student> toggleActive(String id);

  /// Borrado físico — el backend lo rechaza (400) si el alumno sigue activo;
  /// hay que darlo de baja primero. También puede rechazarlo (409) si tiene
  /// registros asociados (asistencias, pulsera NFC, etc.).
  Future<void> eliminarAlumno(String id);
}
