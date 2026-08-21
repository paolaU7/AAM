import '../entities/student.dart';
import '../repositories/student_repository.dart';

/// Alta manual de alumno. El curso se elige en el frontend (año lectivo →
/// año de cursada → división, resueltos contra los cursos existentes) y se
/// envía como `courseId` — la unicidad del DNI la valida el backend, acá
/// solo validamos formato.
class CreateStudent {
  const CreateStudent(this.repository);
  final StudentRepository repository;

  Future<Student> call({
    required String firstName,
    required String lastName,
    required String nationalId,
    required String courseId,
    String? workshopGroupId,
  }) async {
    final nombre = firstName.trim();
    final apellido = lastName.trim();
    final dni = nationalId.trim();

    if (nombre.isEmpty || apellido.isEmpty || dni.isEmpty) {
      throw const CreateStudentException('Completá nombre, apellido y DNI.');
    }
    if (!RegExp(r'^\d{7,8}$').hasMatch(dni)) {
      throw const CreateStudentException('El DNI debe tener 7 u 8 dígitos.');
    }
    if (courseId.isEmpty) {
      throw const CreateStudentException('Seleccioná año lectivo, año de cursada y división.');
    }

    return repository.crearAlumno(
      firstName: nombre,
      lastName: apellido,
      nationalId: dni,
      courseId: courseId,
      workshopGroupId: workshopGroupId,
    );
  }
}

class CreateStudentException implements Exception {
  const CreateStudentException(this.message);
  final String message;

  @override
  String toString() => message;
}
