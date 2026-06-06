/// Entidad de dominio: Curso
class Curso {
  const Curso({
    required this.id,
    required this.anio,
    required this.division,
    required this.especialidad,
    required this.turno,
    required this.totalAlumnos,
    this.preceptorId,
    this.horarioIngreso,
    this.horarioEgreso,
  });

  final String id;
  final int anio;           // 1–6
  final String division;    // "1°", "2°", "3°"
  final String especialidad;
  final String turno;       // "mañana" | "tarde" | "vespertino"
  final int totalAlumnos;
  final String? preceptorId;
  final String? horarioIngreso; // "08:00"
  final String? horarioEgreso;  // "12:20"

  String get nombre => '$anio° $division° — $especialidad';
  String get horario =>
      (horarioIngreso != null && horarioEgreso != null)
          ? '$horarioIngreso – $horarioEgreso'
          : '';

  Curso copyWith({
    String? id,
    int? anio,
    String? division,
    String? especialidad,
    String? turno,
    int? totalAlumnos,
    String? preceptorId,
    String? horarioIngreso,
    String? horarioEgreso,
  }) {
    return Curso(
      id:             id             ?? this.id,
      anio:           anio           ?? this.anio,
      division:       division       ?? this.division,
      especialidad:   especialidad   ?? this.especialidad,
      turno:          turno          ?? this.turno,
      totalAlumnos:   totalAlumnos   ?? this.totalAlumnos,
      preceptorId:    preceptorId    ?? this.preceptorId,
      horarioIngreso: horarioIngreso ?? this.horarioIngreso,
      horarioEgreso:  horarioEgreso  ?? this.horarioEgreso,
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
