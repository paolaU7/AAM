import '../entities/student.dart';
import '../repositories/student_repository.dart';

class GetStudents {
  const GetStudents(this.repository);
  final StudentRepository repository;

  Future<List<Student>> call({String? cursoId}) async {
    if (cursoId != null) {
      return repository.getAlumnosPorCurso(cursoId);
    }
    return repository.getAlumnos();
  }
}

class GetStudentsAtRisk {
  const GetStudentsAtRisk(this.repository);
  final StudentRepository repository;

  /// Retorna alumnos con asistencia < 75% (umbral RITE)
  Future<List<Student>> call() async {
    final todos = await repository.getAlumnos();
    return todos
        .where((a) => a.estadoRegularidad != EstadoRegularidad.regular)
        .toList()
      ..sort((a, b) => a.porcentajeAsistencia.compareTo(b.porcentajeAsistencia));
  }
}
