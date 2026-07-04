import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/student.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/workshop_group.dart';

class ApiDatasource {
  static const String baseUrl = 'http://localhost:8000';

  Future<List<Student>> getAlumnos() async {
    final response = await http
        .get(Uri.parse('$baseUrl/alumnos'))
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

  // ── Grupos de taller (N:M con alumnos) ──────────────────────────────────────

  Future<List<WorkshopGroup>> getWorkshopGroups() async {
    final response = await http.get(Uri.parse('$baseUrl/workshop-groups'));
    if (response.statusCode != 200) throw Exception('Error al obtener grupos de taller');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => WorkshopGroup.fromJson(j)).toList();
  }

  Future<List<WorkshopGroup>> getWorkshopGroupsDeAlumno(String alumnoId) async {
    final response = await http.get(Uri.parse('$baseUrl/students/$alumnoId/workshop-groups'));
    if (response.statusCode != 200) throw Exception('Error al obtener talleres del alumno');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => WorkshopGroup.fromJson(j)).toList();
  }

  Future<List<WorkshopGroup>> agregarWorkshopGroupAAlumno(String alumnoId, int workshopGroupId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/students/$alumnoId/workshop-groups'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'workshop_group_id': workshopGroupId}),
    );
    if (response.statusCode != 201) throw Exception('Error al asignar taller');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => WorkshopGroup.fromJson(j)).toList();
  }

  Future<void> quitarWorkshopGroupDeAlumno(String alumnoId, int workshopGroupId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/students/$alumnoId/workshop-groups/$workshopGroupId'),
    );
    if (response.statusCode != 204) throw Exception('Error al quitar taller');
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
      turno: json['turno'],
      recursante: json['recursante'] ?? false,
      porcentajeAsistencia: (json['porcentaje_asistencia'] as num).toDouble(),
    );
  }

  Course _cursoFromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'].toString(),
      academicYear: json['anio'].toString(),
      division: json['division'] ?? '',
      specialty: json['especialidad'] ?? '',
      shift: json['turno'] ?? '',
      workshopGroups: (json['workshop_groups'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      totalStudents: json['total_alumnos'] ?? 0,
      name: json['nombre'],
      schedule: json['horario'],
    );
  }
}