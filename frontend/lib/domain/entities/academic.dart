/// Catálogo global de materias, reutilizable entre cursos y años.
class Subject {
  const Subject({required this.id, required this.name});
  final String id;
  final String name;

  factory Subject.fromJson(Map<String, dynamic> json) =>
      Subject(id: json['id'].toString(), name: json['name']);
}

/// Profesor — dato de referencia para el horario. No tiene login.
class Teacher {
  const Teacher({required this.id, required this.fullName, this.email, this.phone});
  final String id;
  final String fullName;
  final String? email;
  final String? phone;

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
        id: json['id'].toString(),
        fullName: json['full_name'],
        email: json['email'],
        phone: json['phone'],
      );
}

/// Qué materia dicta qué profesor, EN un curso puntual.
class SubjectTeacherAssignment {
  const SubjectTeacherAssignment({
    required this.courseId,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    this.teacherEmail,
    this.teacherPhone,
  });

  final String courseId;
  final String subjectId;
  final String subjectName;
  final String teacherId;
  final String teacherName;
  final String? teacherEmail;
  final String? teacherPhone;

  factory SubjectTeacherAssignment.fromJson(Map<String, dynamic> json) => SubjectTeacherAssignment(
        courseId: json['course_id'].toString(),
        subjectId: json['subject_id'].toString(),
        subjectName: json['subject_name'],
        teacherId: json['teacher_id'].toString(),
        teacherName: json['teacher_name'],
        teacherEmail: json['teacher_email'],
        teacherPhone: json['teacher_phone'],
      );
}
