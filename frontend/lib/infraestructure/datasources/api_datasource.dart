import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/alumno.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/workshop_group.dart';

class ApiDatasource {
  static const String baseUrl = 'http://localhost:8000';

  Future<List<Alumno>> getAlumnos() async {
    final response = await http.get(Uri.parse('$baseUrl/alumnos'));
    if (response.statusCode != 200) throw Exception('Error al obtener alumnos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => _alumnoFromJson(json)).toList();
  }

  Future<List<Curso>> getCursos() async {
    final response = await http.get(Uri.parse('$baseUrl/courses'));
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

  Alumno _alumnoFromJson(Map<String, dynamic> json) {
    return Alumno(
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

  Curso _cursoFromJson(Map<String, dynamic> json) {
    return Curso(
      id: json['id'].toString(),
      anio: json['anio'].toString(),
      division: json['division'] ?? '',
      especialidad: json['especialidad'] ?? '',
      turno: json['turno'] ?? '',
      workshopGroups: (json['workshop_groups'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      totalAlumnos: json['total_alumnos'] ?? 0,
      nombre: json['nombre'],
      horario: json['horario'],
    );
  }
}