import '../entities/alumno.dart';
import '../repositories/alumno_repository.dart';

class GetAlumnos {
  const GetAlumnos(this.repository);
  final AlumnoRepository repository;

  Future<List<Alumno>> call({String? cursoId}) async {
    if (cursoId != null) {
      return repository.getAlumnosPorCurso(cursoId);
    }
    return repository.getAlumnos();
  }
}

class GetAlumnosEnRiesgo {
  const GetAlumnosEnRiesgo(this.repository);
  final AlumnoRepository repository;

  /// Retorna alumnos con asistencia < 75% (umbral RITE)
  Future<List<Alumno>> call() async {
    final todos = await repository.getAlumnos();
    return todos
        .where((a) => a.estadoRegularidad != EstadoRegularidad.regular)
        .toList()
      ..sort((a, b) => a.porcentajeAsistencia.compareTo(b.porcentajeAsistencia));
  }
}
