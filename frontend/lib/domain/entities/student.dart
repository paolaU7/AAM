/// Entidad de dominio: Student (Alumno)
/// Sin dependencias externas — solo Dart puro.
class Student {
  const Student({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.cursoId,
    required this.curso,
    required this.recursante,
    required this.porcentajeAsistencia,
    this.workshopGroupId,
    this.taller,
  });

  final String id;           // ULID
  final String nombre;
  final String apellido;
  final String dni;
  final String cursoId;
  final String curso;        // ej. "4to 2da (2026)"
  final bool recursante;
  final double porcentajeAsistencia; // 0.0 – 100.0
  final String? workshopGroupId; // grupo de taller — 1 solo, dentro de su curso
  final String? taller;          // group_label legible, si tiene grupo asignado

  String get nombreCompleto => '$apellido, $nombre';

  /// Regularidad según RITE (75% mínimo)
  EstadoRegularidad get estadoRegularidad {
    if (porcentajeAsistencia < 65) return EstadoRegularidad.enRiesgo;
    if (porcentajeAsistencia < 75) return EstadoRegularidad.irregular;
    return EstadoRegularidad.regular;
  }

  Student copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? dni,
    String? cursoId,
    String? curso,
    bool? recursante,
    double? porcentajeAsistencia,
    String? workshopGroupId,
    bool clearWorkshopGroupId = false,
    String? taller,
  }) {
    return Student(
      id:                    id                    ?? this.id,
      nombre:                nombre                ?? this.nombre,
      apellido:              apellido              ?? this.apellido,
      dni:                   dni                   ?? this.dni,
      cursoId:               cursoId               ?? this.cursoId,
      curso:                 curso                 ?? this.curso,
      recursante:            recursante            ?? this.recursante,
      porcentajeAsistencia:  porcentajeAsistencia  ?? this.porcentajeAsistencia,
      workshopGroupId: clearWorkshopGroupId ? null : (workshopGroupId ?? this.workshopGroupId),
      taller:                taller                ?? this.taller,
    );
  }
}

enum EstadoRegularidad { regular, irregular, enRiesgo }
