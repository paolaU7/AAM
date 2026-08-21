import '../../domain/entities/student.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/workshop_group.dart';
import '../../domain/repositories/student_repository.dart';
import '../datasources/api_datasource.dart';

class StudentRepositoryImpl implements StudentRepository {
  StudentRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;

  @override
  Future<List<Student>> getAlumnos() => _datasource.getAlumnos();

  @override
  Future<List<Student>> getAlumnosPorCurso(String cursoId) async {
    final alumnos = await _datasource.getAlumnos();
    return alumnos.where((a) => a.cursoId == cursoId).toList();
  }

  @override
  Future<Student?> getAlumnoPorId(String id) async {
    final alumnos = await _datasource.getAlumnos();
    try {
      return alumnos.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Student?> getAlumnoPorDni(String dni) async {
    final alumnos = await _datasource.getAlumnos();
    try {
      return alumnos.firstWhere((a) => a.dni == dni);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Course>> getCourses() => _datasource.getCursos();

  @override
  Future<List<WorkshopGroup>> getWorkshopGroupsByCourse(String courseId) =>
      _datasource.getWorkshopGroupsByCourse(courseId);

  @override
  Future<Student> crearAlumno({
    required String firstName,
    required String lastName,
    required String nationalId,
    required String courseId,
    String? workshopGroupId,
  }) =>
      _datasource.crearAlumno(
        firstName: firstName,
        lastName: lastName,
        nationalId: nationalId,
        courseId: courseId,
        workshopGroupId: workshopGroupId,
      );

  @override
  Future<Student> actualizarAlumno(Student alumno) => _datasource.actualizarAlumno(alumno);
}
