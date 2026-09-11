import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/student.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/workshop_group.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/academic.dart';
import '../../domain/entities/class_period.dart';
import '../../domain/entities/preceptor_assignment.dart';
import '../../domain/entities/specialty.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/config.dart';

/// Error de API que expone el mensaje del backend tal cual (para mostrarlo al
/// usuario, p.ej. "Ya existe un alumno registrado con ese DNI.").
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiDatasource {
  static const String baseUrl = 'http://localhost:8000';

  /// Por default trae solo alumnos activos — los dados de baja quedan
  /// afuera de cualquier selector (asistencia manual, alumnos en riesgo,
  /// etc.) salvo que se pida explícitamente lo contrario.
  Future<List<Student>> getAlumnos({bool incluirInactivos = false}) async {
    final response = await http
        .get(Uri.parse('$baseUrl/alumnos?incluir_inactivos=$incluirInactivos'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener alumnos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => _alumnoFromJson(json)).toList();
  }

  Future<List<Course>> getCursos() async {
    final response = await http
        .get(Uri.parse('$baseUrl/courses'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener cursos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => _cursoFromJson(json)).toList();
  }

  Future<Course> crearCurso({
    required int academicYear,
    required int gradeYear,
    required int division,
    required String specialtyId,
  }) async {
    final body = {
      'academic_year': academicYear,
      'grade_year': gradeYear,
      'division': division,
      'specialty_id': specialtyId,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/courses'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) {
      return _cursoFromJson(jsonDecode(response.body));
    }
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo crear el curso.');
  }

  Future<Course> actualizarCurso({
    required String id,
    required int academicYear,
    required int gradeYear,
    required int division,
    required String specialtyId,
  }) async {
    final body = {
      'academic_year': academicYear,
      'grade_year': gradeYear,
      'division': division,
      'specialty_id': specialtyId,
    };
    final response = await http
        .patch(
          Uri.parse('$baseUrl/courses/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return _cursoFromJson(jsonDecode(response.body));
    }
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo actualizar el curso.');
  }

  // ── Especialidades y configuración general ──────────────────────────────────

  Future<List<Specialty>> getSpecialties() async {
    final response = await http.get(Uri.parse('$baseUrl/specialties')).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener especialidades');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => Specialty.fromJson(j)).toList();
  }

  Future<SchoolSettings> getSchoolSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/school-settings')).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener la configuración del colegio');
    return SchoolSettings.fromJson(jsonDecode(response.body));
  }

  // ── Notificaciones (campana del header) ──────────────────────────────────────
  // Se calculan al vuelo cada vez que se piden — no hay tabla ni estado de
  // leído/no leído.
  Future<List<AppNotification>> getNotifications() async {
    final response = await http.get(Uri.parse('$baseUrl/notifications')).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener notificaciones');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => AppNotification.fromJson(j)).toList();
  }

  // ── Alta manual en cascada (año lectivo → año de cursada → división) ───────
  // Sin tablas catálogo: los selectores se arman en el frontend a partir de
  // los cursos ya existentes (ver getCursos / StudentRepository.getCourses).
  // El grupo de taller es un FK simple y opcional en students, scoped al
  // curso ya resuelto (ver getWorkshopGroupsByCourse).

  Future<Student> crearAlumno({
    required String firstName,
    required String lastName,
    required String nationalId,
    required String courseId,
    String? workshopGroupId,
  }) async {
    final body = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'national_id': nationalId,
      'course_id': courseId,
      'workshop_group_id': ?workshopGroupId,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/alumnos'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) {
      return _alumnoFromJson(jsonDecode(response.body));
    }
    // El backend devuelve {"detail": "..."} con el motivo (p.ej. DNI duplicado).
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo crear el alumno.');
  }

  Future<Student> actualizarAlumno(Student alumno) async {
    final body = <String, dynamic>{
      'nombre': alumno.nombre,
      'apellido': alumno.apellido,
      'dni': alumno.dni,
      'curso_id': alumno.cursoId,
      'workshop_group_id': alumno.workshopGroupId,
    };
    final response = await http
        .put(
          Uri.parse('$baseUrl/alumnos/${alumno.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return _alumnoFromJson(jsonDecode(response.body));
    }
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo actualizar el alumno.');
  }

  /// Baja/alta lógica — no borra al alumno del sistema.
  Future<Student> toggleActiveAlumno(String id) async {
    final response = await http
        .post(Uri.parse('$baseUrl/alumnos/$id/toggle-active'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return _alumnoFromJson(jsonDecode(response.body));
    }
    throw ApiException('No se pudo cambiar el estado del alumno.');
  }

  // ── Horarios (time_slots) ────────────────────────────────────────────────────

  Future<List<TimeSlot>> getTimeSlotsByCourse(String courseId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/courses/$courseId/time-slots'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los horarios del curso');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => TimeSlot.fromJson(j)).toList();
  }

  Future<List<TimeSlot>> getTimeSlotsByWorkshopGroup(String workshopGroupId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/workshop-groups/$workshopGroupId/time-slots'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los horarios del taller');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => TimeSlot.fromJson(j)).toList();
  }

  /// Franja del turno principal (curricular o contraturno) — no de taller.
  Future<TimeSlot> crearTimeSlotDeCurso({
    required String courseId,
    required ShiftType shift,
    required ActivityType activityType,
    required int dayOfWeek,
    required ClockTime startTime,
    required ClockTime endTime,
    int lateToleranceMinutes = 0,
  }) async {
    final body = {
      'shift': shiftTypeToJson(shift),
      'activity_type': activityTypeToJson(activityType),
      'day_of_week': dayOfWeek,
      'start_time': startTime.toJson(),
      'end_time': endTime.toJson(),
      'late_tolerance_minutes': lateToleranceMinutes,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/courses/$courseId/time-slots'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return TimeSlot.fromJson(jsonDecode(response.body));
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo crear la franja horaria.');
  }

  Future<void> eliminarTimeSlot(String courseId, String slotId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/courses/$courseId/time-slots/$slotId'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) throw Exception('No se pudo eliminar la franja horaria.');
  }

  // ── Horario detallado (class_periods) ───────────────────────────────────────

  Future<List<ClassPeriod>> getClassPeriods(String courseId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/courses/$courseId/class-periods'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener el horario detallado');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => ClassPeriod.fromJson(j)).toList();
  }

  Future<ClassPeriod> crearClassPeriod({
    required String courseId,
    required int dayOfWeek,
    required ShiftType shift,
    required PeriodType periodType,
    required ClockTime startTime,
    required ClockTime endTime,
    String? subjectId,
    String? teacherId,
    bool isFifthModule = false,
    String? workshopGroupId,
  }) async {
    final body = {
      'day_of_week': dayOfWeek,
      'shift': shiftTypeToJson(shift),
      'period_type': periodTypeToJson(periodType),
      'start_time': startTime.toJson(),
      'end_time': endTime.toJson(),
      'subject_id': ?subjectId,
      'teacher_id': ?teacherId,
      'is_fifth_module': isFifthModule,
      'workshop_group_id': ?workshopGroupId,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/courses/$courseId/class-periods'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return ClassPeriod.fromJson(jsonDecode(response.body));
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo crear el período.');
  }

  Future<void> eliminarClassPeriod(String courseId, String periodId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/courses/$courseId/class-periods/$periodId'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) throw Exception('No se pudo eliminar el período.');
  }

  // ── Materias y profesores (catálogos globales) ──────────────────────────────

  /// Sin filtros: catálogo completo (pantalla Materias). Con
  /// gradeYear+specialtyId: solo lo habilitado para esa combinación puntual
  /// (desplegable al armar el horario de un curso).
  Future<List<Subject>> getSubjects({int? gradeYear, String? specialtyId}) async {
    final query = <String, String>{
      'grade_year': ?(gradeYear != null ? '$gradeYear' : null),
      'specialty_id': ?specialtyId,
    };
    final uri = Uri.parse('$baseUrl/subjects').replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener materias');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => Subject.fromJson(j)).toList();
  }

  Future<Subject> crearSubject({required String name, required SubjectType subjectType}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/subjects'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'subject_type': subjectTypeToJson(subjectType)}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return Subject.fromJson(jsonDecode(response.body));
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo crear la materia.');
  }

  Future<List<SubjectApplicability>> getSubjectApplicability(String subjectId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/subjects/$subjectId/applicability'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener la aplicabilidad de la materia');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => SubjectApplicability.fromJson(j)).toList();
  }

  Future<SubjectApplicability> agregarSubjectApplicability({
    required String subjectId,
    required int gradeYear,
    required String specialtyId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/subjects/$subjectId/applicability'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'grade_year': gradeYear, 'specialty_id': specialtyId}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return SubjectApplicability.fromJson(jsonDecode(response.body));
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo agregar la aplicabilidad.');
  }

  Future<void> quitarSubjectApplicability(String subjectId, String applicabilityId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/subjects/$subjectId/applicability/$applicabilityId'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) throw Exception('No se pudo quitar la aplicabilidad.');
  }

  Future<List<Teacher>> getTeachers() async {
    final response = await http.get(Uri.parse('$baseUrl/teachers')).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener profesores');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => Teacher.fromJson(j)).toList();
  }

  Future<Teacher> crearTeacher({required String fullName, String? email, String? phone}) async {
    final body = {
      'full_name': fullName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/teachers'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return Teacher.fromJson(jsonDecode(response.body));
    throw ApiException('No se pudo crear el profesor.');
  }

  /// Todas las asignaciones (curso + materia) de UN profesor — ficha de
  /// Profes. No distingue grupo de taller ni reemplazos (eso vive en
  /// class_periods).
  Future<List<SubjectTeacherAssignment>> getTeacherAssignments(String teacherId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/teachers/$teacherId/assignments'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener las asignaciones del profesor');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => SubjectTeacherAssignment.fromJson(j)).toList();
  }

  // ── Materias y profesores DE UN curso ────────────────────────────────────────

  Future<List<SubjectTeacherAssignment>> getCourseSubjectTeachers(String courseId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/courses/$courseId/subject-teachers'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener materias del curso');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => SubjectTeacherAssignment.fromJson(j)).toList();
  }

  Future<SubjectTeacherAssignment> asignarCourseSubjectTeacher({
    required String courseId,
    required String subjectId,
    required String teacherId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/courses/$courseId/subject-teachers'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'subject_id': subjectId, 'teacher_id': teacherId}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return SubjectTeacherAssignment.fromJson(jsonDecode(response.body));
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo asignar la materia.');
  }

  Future<void> quitarCourseSubjectTeacher(String courseId, String subjectId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/courses/$courseId/subject-teachers/$subjectId'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) throw Exception('No se pudo quitar la materia.');
  }

  // ── Preceptores del curso ─────────────────────────────────────────────────────

  Future<List<CoursePreceptor>> getCoursePreceptors(String courseId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/courses/$courseId/preceptors'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los preceptores del curso');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => CoursePreceptor.fromJson(j)).toList();
  }

  Future<CoursePreceptor> asignarCoursePreceptor({
    required String courseId,
    required ShiftType shift,
    required String preceptorId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/courses/$courseId/preceptors'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'shift': shiftTypeToJson(shift), 'preceptor_id': preceptorId}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return CoursePreceptor.fromJson(jsonDecode(response.body));
    throw ApiException('No se pudo asignar el preceptor.');
  }

  Future<void> quitarCoursePreceptor(String courseId, ShiftType shift) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/courses/$courseId/preceptors/${shiftTypeToJson(shift)}'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) throw Exception('No se pudo quitar el preceptor.');
  }

  Future<List<CoursePreceptorTempAssignment>> getCoursePreceptorTempAssignments(String courseId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/courses/$courseId/preceptor-temp-assignments'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los reemplazos temporales');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => CoursePreceptorTempAssignment.fromJson(j)).toList();
  }

  Future<CoursePreceptorTempAssignment> crearCoursePreceptorTempAssignment({
    required String courseId,
    required ShiftType shift,
    required String preceptorId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required String createdByUserId,
  }) async {
    final body = {
      'shift': shiftTypeToJson(shift),
      'preceptor_id': preceptorId,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      'created_by': createdByUserId,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/courses/$courseId/preceptor-temp-assignments'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return CoursePreceptorTempAssignment.fromJson(jsonDecode(response.body));
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo crear el reemplazo temporal.');
  }

  Future<void> eliminarCoursePreceptorTempAssignment(String courseId, String assignmentId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/courses/$courseId/preceptor-temp-assignments/$assignmentId'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 204) throw Exception('No se pudo eliminar el reemplazo temporal.');
  }

  // ── Grupos de taller ─────────────────────────────────────────────────────────
  // Subdivisión interna de UN curso puntual (FK simple y nullable en
  // students) — no se comparten entre cursos.

  /// Catálogo completo sin filtrar por curso — lo usa Horarios.
  Future<List<WorkshopGroup>> getWorkshopGroups() async {
    final response = await http.get(Uri.parse('$baseUrl/workshop-groups'));
    if (response.statusCode != 200) throw Exception('Error al obtener grupos de taller');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => WorkshopGroup.fromJson(j)).toList();
  }

  /// Grupos de UN curso puntual — lo usa Alumnos (alta y edición).
  Future<List<WorkshopGroup>> getWorkshopGroupsByCourse(String courseId) async {
    final response = await http.get(Uri.parse('$baseUrl/courses/$courseId/workshop-groups'));
    if (response.statusCode != 200) throw Exception('Error al obtener los grupos de taller del curso');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => WorkshopGroup.fromJson(j)).toList();
  }

  Student _alumnoFromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'].toString(),
      nombre: json['nombre'],
      apellido: json['apellido'],
      dni: json['dni'],
      cursoId: json['curso_id'].toString(),
      curso: json['curso'],
      especialidad: json['especialidad'],
      recursante: json['recursante'] ?? false,
      porcentajeAsistencia: (json['porcentaje_asistencia'] as num).toDouble(),
      academicYear: (json['academic_year'] as num?)?.toInt() ?? 0,
      gradeYear: (json['grade_year'] as num?)?.toInt() ?? 0,
      division: (json['division'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] ?? true,
      workshopGroupId: json['workshop_group_id']?.toString(),
      taller: json['taller'],
    );
  }

  Course _cursoFromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'].toString(),
      academicYear: (json['academic_year'] as num).toInt(),
      gradeYear: (json['grade_year'] as num).toInt(),
      division: (json['division'] as num).toInt(),
      specialtyId: json['specialty_id'].toString(),
      specialtyName: json['specialty_name'] ?? '',
      totalStudents: json['total_students'] ?? 0,
      name: json['name'],
    );
  }

  // ── Usuarios ──────────────────────────────────────────────────────────────

  Future<List<User>> getUsers() async {
    final response = await http
        .get(Uri.parse('$baseUrl/users'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener usuarios');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => _userFromJson(j)).toList();
  }

  Future<CreatedUser> crearUsuario({
    required String firstName,
    required String lastName,
    required UserRole role,
  }) async {
    final body = {
      'nombre': firstName,
      'apellido': lastName,
      'rol': role.name,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/users'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return CreatedUser(
        user: _userFromJson(data['usuario']),
        temporaryPassword: data['password_temporal'],
      );
    }
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo crear el usuario.');
  }

  Future<User> toggleUserActive(String userId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/users/$userId/toggle-active'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al cambiar el estado del usuario');
    return _userFromJson(jsonDecode(response.body));
  }

  Future<String> resetUserPassword(String userId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/users/$userId/reset-password'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al reiniciar la contraseña');
    final data = jsonDecode(response.body);
    return data['password_temporal'];
  }

  Future<User> actualizarUsuario({
    required String id,
    required String firstName,
    required String lastName,
    required UserRole role,
  }) async {
    final body = {
      'nombre': firstName,
      'apellido': lastName,
      'rol': role.name,
    };
    final response = await http
        .put(
          Uri.parse('$baseUrl/users/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return _userFromJson(jsonDecode(response.body));
    }
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo actualizar el usuario.');
  }

  /// Borrado físico — puede rechazarse (409) si el usuario tiene registros
  /// asociados (asistencias, asignaciones de preceptor, etc.).
  Future<void> eliminarUsuario(String id) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/users/$id'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 204) return;
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    throw ApiException(detail.isNotEmpty ? detail : 'No se pudo eliminar el usuario.');
  }

  User _userFromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      firstName: json['nombre'],
      lastName: json['apellido'],
      username: json['username'],
      email: json['email'],
      role: json['rol'] == 'principal' ? UserRole.principal : UserRole.preceptor,
      isActive: json['activo'] ?? true,
    );
  }

  // ── Asistencia ────────────────────────────────────────────────────────────

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<AttendanceRecord>> getRegistros(String courseId, DateTime date) async {
    final uri = Uri.parse('$baseUrl/attendance').replace(queryParameters: {
      'course_id': courseId,
      'date': _dateOnly(date),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener la asistencia');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => _registroFromJson(j)).toList();
  }

  Future<AttendanceSummary> getResumen(DateTime date, {String? shift}) async {
    final uri = Uri.parse('$baseUrl/attendance/summary').replace(queryParameters: {
      'date': _dateOnly(date),
      'shift': ?shift,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener el resumen de asistencia');
    return _resumenFromJson(jsonDecode(response.body));
  }

  Future<AttendanceRecord> registrarIngresoManual({
    required String studentId,
    required String courseId,
    required DateTime entryTimestamp,
    required AttendanceStatus status,
  }) async {
    final body = {
      'student_id': studentId,
      'course_id': courseId,
      'entry_timestamp': entryTimestamp.toIso8601String(),
      'status': _statusToJson(status),
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/attendance/manual'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) throw Exception('No se pudo registrar el ingreso manual');
    return _registroFromJson(jsonDecode(response.body));
  }

  Future<AttendanceRecord> registrarRetiroAnticipado({
    required String recordId,
    required DateTime departureTime,
    required String reason,
    required String registeredByUserId,
  }) async {
    final body = {
      'departure_time': departureTime.toIso8601String(),
      'reason': reason,
      'registered_by': registeredByUserId,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/attendance/$recordId/early-departure'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('No se pudo registrar el retiro anticipado');
    return _registroFromJson(jsonDecode(response.body));
  }

  Future<AttendanceRecord> marcarNoComputable(String recordId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/attendance/$recordId/mark-non-computable'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('No se pudo marcar como no computable');
    return _registroFromJson(jsonDecode(response.body));
  }

  AttendanceRecord _registroFromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'].toString(),
      studentId: json['student_id'].toString(),
      studentName: json['student_name'] ?? '',
      courseId: json['course_id'].toString(),
      entryTimestamp: DateTime.parse(json['entry_timestamp']),
      source: _sourceFromJson(json['source']),
      status: _statusFromJson(json['status']),
      departureTime: json['departure_time'] != null ? DateTime.parse(json['departure_time']) : null,
      departureReason: json['departure_reason'],
    );
  }

  AttendanceSummary _resumenFromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      date: DateTime.parse(json['date']),
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      late: json['late'] ?? 0,
      nonComputableAbsence: json['non_computable_absence'] ?? 0,
      earlyDepartures: json['early_departures'] ?? 0,
      total: json['total'] ?? 0,
    );
  }

  AttendanceSource _sourceFromJson(String raw) => switch (raw) {
        'nfc' => AttendanceSource.nfc,
        'qr' => AttendanceSource.qr,
        _ => AttendanceSource.manual,
      };

  AttendanceStatus _statusFromJson(String raw) => switch (raw) {
        'present' => AttendanceStatus.present,
        'late' => AttendanceStatus.late,
        'absent_with_presence' => AttendanceStatus.absentWithPresence,
        'non_computable_absence' => AttendanceStatus.nonComputableAbsence,
        _ => AttendanceStatus.absent,
      };

  String _statusToJson(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => 'present',
        AttendanceStatus.late => 'late',
        AttendanceStatus.absent => 'absent',
        AttendanceStatus.absentWithPresence => 'absent_with_presence',
        AttendanceStatus.nonComputableAbsence => 'non_computable_absence',
      };

  // ══ Configuración (Panel de Dirección) ═════════════════════════════════════
  // Consume los endpoints /config/* del backend Go. Especialidades, materias y
  // profesores YA NO se gestionan acá — sus pantallas propias del sidebar
  // conservan esas rutas de paridad. Los errores llegan como {"detail": "..."}.

  ApiException _detailError(http.Response response, String fallback) {
    String detail = '';
    try {
      detail = (jsonDecode(response.body)['detail'] ?? '').toString();
    } catch (_) {}
    return ApiException(detail.isNotEmpty ? detail : fallback);
  }

  // ── General: alertas + almuerzo (school_settings) ─────────────────────────

  Future<ConfigSchoolSettings> getConfigSchoolSettings() async {
    final response = await http
        .get(Uri.parse('$baseUrl/config/school-settings'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener la configuración');
    return ConfigSchoolSettings.fromJson(jsonDecode(response.body));
  }

  Future<ConfigSchoolSettings> actualizarConfigSchoolSettings(ConfigSchoolSettings settings) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/config/school-settings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(settings.toJson()),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return ConfigSchoolSettings.fromJson(jsonDecode(response.body));
    throw _detailError(response, 'No se pudo guardar la configuración.');
  }

  // ── General: turnos (etiqueta editable) ──────────────────────────────────

  Future<List<ShiftConfig>> getShifts() async {
    final response = await http.get(Uri.parse('$baseUrl/config/shifts')).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los turnos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => ShiftConfig.fromJson(j)).toList();
  }

  Future<ShiftConfig> renombrarShift(String shift, String label) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/config/shifts/$shift'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'label': label}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return ShiftConfig.fromJson(jsonDecode(response.body));
    throw _detailError(response, 'No se pudo actualizar el turno.');
  }

  // ── General: recreos por turno (shift_breaks) ────────────────────────────

  Future<List<ShiftBreak>> getShiftBreaks(String shift) async {
    final response = await http
        .get(Uri.parse('$baseUrl/config/shift-breaks').replace(queryParameters: {'shift': shift}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los recreos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => ShiftBreak.fromJson(j)).toList();
  }

  Future<ShiftBreak> crearShiftBreak({
    required String shift,
    String? label,
    required String startTime,
    required String endTime,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/config/shift-breaks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'shift': shift,
            if (label != null && label.isNotEmpty) 'label': label,
            'start_time': startTime,
            'end_time': endTime,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return ShiftBreak.fromJson(jsonDecode(response.body));
    throw _detailError(response, 'No se pudo crear el recreo.');
  }

  Future<void> eliminarShiftBreak(String id) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/config/shift-breaks/$id'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 204) return;
    throw _detailError(response, 'No se pudo eliminar el recreo.');
  }

  // ── Cursos: estructura académica ────────────────────────────────────────

  Future<CoursesStructure> getCoursesStructure() async {
    final response = await http
        .get(Uri.parse('$baseUrl/config/courses/structure'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener la estructura de cursos');
    return CoursesStructure.fromJson(jsonDecode(response.body));
  }

  Future<CoursesStructure> guardarCoursesStructure(CoursesStructure structure) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/config/courses/structure'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(structure.toJson()),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return CoursesStructure.fromJson(jsonDecode(response.body));
    throw _detailError(response, 'No se pudo guardar la estructura.');
  }

  // ── Dispositivos: puntos de acceso + lectores ───────────────────────────

  Future<List<EntryPoint>> getEntryPoints() async {
    final response = await http
        .get(Uri.parse('$baseUrl/config/entry-points'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los puntos de acceso');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => EntryPoint.fromJson(j)).toList();
  }

  Future<EntryPoint> crearEntryPoint({required String name, String? location}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/config/entry-points'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            if (location != null && location.isNotEmpty) 'location': location,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return EntryPoint.fromJson(jsonDecode(response.body));
    throw _detailError(response, 'No se pudo crear el punto de acceso.');
  }

  Future<EntryPoint> actualizarEntryPoint({required String id, required String name, String? location}) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/config/entry-points/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            if (location != null && location.isNotEmpty) 'location': location,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) return EntryPoint.fromJson(jsonDecode(response.body));
    throw _detailError(response, 'No se pudo actualizar el punto de acceso.');
  }

  Future<void> eliminarEntryPoint(String id) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/config/entry-points/$id'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 204) return;
    throw _detailError(response, 'No se pudo eliminar el punto de acceso.');
  }

  Future<List<ReaderDevice>> getConfigDevices() async {
    final response = await http
        .get(Uri.parse('$baseUrl/config/devices'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Error al obtener los dispositivos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => ReaderDevice.fromJson(j)).toList();
  }

  /// La `apiKey` de la respuesta es lo ÚNICO que no se puede volver a ver.
  Future<CreatedDevice> crearConfigDevice({required String entryPointId, required String name}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/config/devices'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'entry_point_id': entryPointId, 'name': name}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 201) return CreatedDevice.fromJson(jsonDecode(response.body));
    throw _detailError(response, 'No se pudo registrar el dispositivo.');
  }

  Future<void> revocarConfigDevice(String id) async {
    final response = await http
        .post(Uri.parse('$baseUrl/config/devices/$id/revoke'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 204) return;
    throw _detailError(response, 'No se pudo revocar el dispositivo.');
  }
}
