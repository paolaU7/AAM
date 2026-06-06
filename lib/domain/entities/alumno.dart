/// Entidad de dominio: Alumno
/// Sin dependencias externas — solo Dart puro.
class Alumno {
  const Alumno({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.cursoId,
    required this.curso,
    required this.especialidad,
    required this.turno,
    required this.recursante,
    required this.porcentajeAsistencia,
  });

  final String id;           // ULID
  final String nombre;
  final String apellido;
  final String dni;
  final String cursoId;
  final String curso;        // ej. "4° 2°"
  final String especialidad; // ej. "Informática"
  final String turno;        // "mañana" | "tarde" | "vespertino"
  final bool recursante;
  final double porcentajeAsistencia; // 0.0 – 100.0

  String get nombreCompleto => '$apellido, $nombre';

  /// Regularidad según RITE (75% mínimo)
  EstadoRegularidad get estadoRegularidad {
    if (porcentajeAsistencia < 65) return EstadoRegularidad.enRiesgo;
    if (porcentajeAsistencia < 75) return EstadoRegularidad.irregular;
    return EstadoRegularidad.regular;
  }

  Alumno copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? dni,
    String? cursoId,
    String? curso,
    String? especialidad,
    String? turno,
    bool? recursante,
    double? porcentajeAsistencia,
  }) {
    return Alumno(
      id:                    id                    ?? this.id,
      nombre:                nombre                ?? this.nombre,
      apellido:              apellido              ?? this.apellido,
      dni:                   dni                   ?? this.dni,
      cursoId:               cursoId               ?? this.cursoId,
      curso:                 curso                 ?? this.curso,
      especialidad:          especialidad          ?? this.especialidad,
      turno:                 turno                 ?? this.turno,
      recursante:            recursante            ?? this.recursante,
      porcentajeAsistencia:  porcentajeAsistencia  ?? this.porcentajeAsistencia,
    );
  }
}

enum EstadoRegularidad { regular, irregular, enRiesgo }
