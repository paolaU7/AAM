/// 'curricular' | 'workshop' — fijo desde el alta de la materia. Si la misma
/// materia se dicta en ambos contextos, son dos filas distintas en el
/// catálogo, no una compartida.
enum SubjectType { curricular, workshop }

SubjectType subjectTypeFromString(String raw) => switch (raw) {
      'curricular' => SubjectType.curricular,
      'workshop' => SubjectType.workshop,
      _ => throw FormatException('subject_type desconocido: $raw'),
    };

String subjectTypeToJson(SubjectType t) => switch (t) {
      SubjectType.curricular => 'curricular',
      SubjectType.workshop => 'workshop',
    };

String subjectTypeLabel(SubjectType t) => switch (t) {
      SubjectType.curricular => 'Curricular',
      SubjectType.workshop => 'Taller',
    };

/// Catálogo global de materias, reutilizable entre cursos y años.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.subjectType,
    this.shortCode = '',
    this.shortCodeAuto = true,
    this.isActive = true,
    this.applicability = const [],
  });
  final String id;
  final String name;
  final SubjectType subjectType;
  // Identificador corto (ej. "M1r4t"). Se autogenera y se recalcula solo
  // mientras shortCodeAuto sea true; editarlo a mano lo pone en false.
  final String shortCode;
  final bool shortCodeAuto;
  // Baja lógica: solo se puede eliminar (borrado físico) una materia
  // inactiva, y solo si no tiene cursos/profesores asociados.
  final bool isActive;
  // GET /subjects la trae embebida (ver backend) — permite filtrar la
  // pantalla Materias por año/especialidad sin pedirla materia por materia.
  // Vacía si el endpoint no la incluyó (p.ej. una respuesta vieja en caché).
  final List<SubjectApplicability> applicability;

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'].toString(),
        name: json['name'],
        subjectType: subjectTypeFromString(json['subject_type']),
        shortCode: (json['short_code'] as String?) ?? '',
        shortCodeAuto: (json['short_code_auto'] as bool?) ?? true,
        isActive: (json['is_active'] as bool?) ?? true,
        applicability: ((json['applicability'] as List?) ?? const [])
            .map((j) => SubjectApplicability.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
}

/// En qué año de cursada (+especialidad, si es 4to o más) se puede dictar
/// una materia. Una materia puede tener varias de estas a la vez.
class SubjectApplicability {
  const SubjectApplicability({
    required this.id,
    required this.subjectId,
    required this.gradeYear,
    required this.specialtyId,
    required this.specialtyName,
  });

  final String id;
  final String subjectId;
  final int gradeYear;
  final String specialtyId;
  final String specialtyName;

  factory SubjectApplicability.fromJson(Map<String, dynamic> json) => SubjectApplicability(
        id: json['id'].toString(),
        subjectId: json['subject_id'].toString(),
        gradeYear: (json['grade_year'] as num).toInt(),
        specialtyId: json['specialty_id'].toString(),
        specialtyName: json['specialty_name'],
      );
}

/// Profesor — dato de referencia para el horario. No tiene login.
class Teacher {
  const Teacher({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.assignments = const [],
  });
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  // GET /teachers la trae embebida (ver backend) — permite mostrar la
  // columna "Materias asignadas" y filtrar por materia sin pedirlas
  // profesor por profesor. Vacía si el endpoint no la incluyó (respuesta
  // vieja en caché).
  final List<SubjectTeacherAssignment> assignments;

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
        id: json['id'].toString(),
        fullName: json['full_name'],
        email: json['email'],
        phone: json['phone'],
        assignments: ((json['assignments'] as List?) ?? const [])
            .map((j) => SubjectTeacherAssignment.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
}

/// Qué materia dicta qué profesor, EN un curso puntual.
class SubjectTeacherAssignment {
  const SubjectTeacherAssignment({
    required this.courseId,
    required this.subjectId,
    required this.subjectName,
    required this.subjectType,
    this.subjectShortCode = '',
    required this.teacherId,
    required this.teacherName,
    this.teacherEmail,
    this.teacherPhone,
    this.courseName,
  });

  final String courseId;
  final String subjectId;
  final String subjectName;
  final SubjectType subjectType;
  // Identificador corto de la materia (ej. "M1r4t") — mismo que se ve en la
  // primera columna de la sección Materias. Se usa para la columna "Materias
  // asignadas" de Profesores, en vez de repetir nombre + curso completos.
  final String subjectShortCode;
  final String teacherId;
  final String teacherName;
  final String? teacherEmail;
  final String? teacherPhone;
  final String? courseName;

  factory SubjectTeacherAssignment.fromJson(Map<String, dynamic> json) => SubjectTeacherAssignment(
        courseId: json['course_id'].toString(),
        subjectId: json['subject_id'].toString(),
        subjectName: json['subject_name'],
        subjectType: subjectTypeFromString(json['subject_type']),
        subjectShortCode: (json['subject_short_code'] as String?) ?? '',
        teacherId: json['teacher_id'].toString(),
        teacherName: json['teacher_name'],
        teacherEmail: json['teacher_email'],
        teacherPhone: json['teacher_phone'],
        courseName: json['course_name'],
      );
}
