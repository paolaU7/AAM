/// Entidad de dominio: Curso
///
/// Refleja el esquema nuevo de la BDD: un curso es la combinación de las cuatro
/// dimensiones independientes (año, división, especialidad, turno). Los grupos
/// de taller ya no forman parte del curso: son una relación N:M aparte
/// (`workshopGroups`).
class Curso {
  const Curso({
    required this.id,
    required this.anio,
    required this.division,
    required this.especialidad,
    required this.turno,
    this.workshopGroups = const [],
    required this.totalAlumnos,
    this.preceptorId,
    String? nombre,
    String? horario,
  })  : _nombre = nombre,
        _horario = horario;

  final String id;
  final String anio;                 // nombre del año lectivo, p.ej. "4"
  final String division;             // "A", "B", "C"...
  final String especialidad;
  final String turno;                // "Mañana" | "Tarde" | "Vespertino"
  final List<String> workshopGroups; // grupos de taller (N:M), p.ej. ["Robótica"]
  final int totalAlumnos;
  final String? preceptorId;

  // Provistos por el backend (CourseResponse). Si faltan, se derivan.
  final String? _nombre;
  final String? _horario;

  String get nombre =>
      _nombre ?? '$anio° $division° — $especialidad — $turno';

  String get horario => _horario ?? '';

  /// Compat: representación de los talleres como texto unido.
  String get grupoTaller => workshopGroups.join(', ');

  Curso copyWith({
    String? id,
    String? anio,
    String? division,
    String? especialidad,
    String? turno,
    List<String>? workshopGroups,
    int? totalAlumnos,
    String? preceptorId,
    String? nombre,
    String? horario,
  }) {
    return Curso(
      id:             id             ?? this.id,
      anio:           anio           ?? this.anio,
      division:       division       ?? this.division,
      especialidad:   especialidad   ?? this.especialidad,
      turno:          turno          ?? this.turno,
      workshopGroups: workshopGroups ?? this.workshopGroups,
      totalAlumnos:   totalAlumnos   ?? this.totalAlumnos,
      preceptorId:    preceptorId    ?? this.preceptorId,
      nombre:         nombre         ?? _nombre,
      horario:        horario        ?? _horario,
    );
  }
}

/// Resumen de asistencia agregado (para dashboard y stats)
class ResumenAsistencia {
  const ResumenAsistencia({
    required this.fecha,
    required this.presentes,
    required this.ausentes,
    required this.tardanzas,
    required this.noComputables,
    required this.retiros,
    required this.total,
  });

  final DateTime fecha;
  final int presentes;
  final int ausentes;
  final int tardanzas;
  final int noComputables;
  final int retiros;
  final int total;

  double get porcentajeAsistencia =>
      total > 0 ? (presentes / total) * 100 : 0;
}
