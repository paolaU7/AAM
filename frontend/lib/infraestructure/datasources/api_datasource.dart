import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/alumno.dart';
import '../../domain/entities/curso.dart';

class ApiDatasource {
  static const String baseUrl = 'http://localhost:8000';

  Future<List<Alumno>> getAlumnos() async {
    final response = await http.get(Uri.parse('$baseUrl/alumnos'));
    if (response.statusCode != 200) throw Exception('Error al obtener alumnos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => _alumnoFromJson(json)).toList();
  }

  Future<List<Curso>> getCursos() async {
    final response = await http.get(Uri.parse('$baseUrl/cursos'));
    if (response.statusCode != 200) throw Exception('Error al obtener cursos');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => _cursoFromJson(json)).toList();
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
      anio: json['anio'],
      division: json['division'],
      grupoTaller: json['grupo_taller'] ?? '',
      especialidad: json['especialidad'] ?? '',
      turno: json['turno'],
      totalAlumnos: json['total_alumnos'] ?? 0,
      horarioIngreso: json['horario_ingreso'],
      horarioEgreso: json['horario_egreso'],
    );
  }
}