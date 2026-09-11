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
    this.especialidad,
    required this.recursante,
    required this.porcentajeAsistencia,
    this.academicYear = 0,
    this.gradeYear = 0,
    this.division = 0,
    this.isActive = true,
    this.workshopGroupId,
    this.taller,
  });

  final String id;           // ULID
  final String nombre;
  final String apellido;
  final String dni;
  final String cursoId;
  final String curso;        // ej. "4to 2da (2026)"
  final String? especialidad; // nombre de la especialidad del curso
  final bool recursante;
  final double porcentajeAsistencia; // 0.0 – 100.0
  // Dimensiones del curso, separadas del label compuesto `curso` para poder
  // mostrarlas/filtrar por columna independiente en la tabla.
  final int academicYear;
  final int gradeYear;
  final int division;
  final bool isActive; // baja lógica — no implica borrado
  final String? workshopGroupId; // grupo de taller — 1 solo, dentro de su curso
  final String? taller;          // group_label legible, si tiene grupo asignado

  String get nombreCompleto => '$apellido, $nombre';

  /// Regularidad según RITE (75% mínimo)
  EstadoRegularidad get estadoRegularidad {
    if (porcentajeAsistencia < 65) return EstadoRegularidad.enRiesgo;
    if (porcentajeAsistencia < 75) return EstadoRegularidad.irregular;
    return EstadoRegularidad.regular;
  }

  /// DNI con puntos de miles para mostrar (ej. "32456789" -> "32.456.789").
  /// Solo para display — nunca usar sobre un campo editable.
  String get dniFormateado {
    final digits = dni.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return dni;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Student copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? dni,
    String? cursoId,
    String? curso,
    String? especialidad,
    bool? recursante,
    double? porcentajeAsistencia,
    int? academicYear,
    int? gradeYear,
    int? division,
    bool? isActive,
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
      especialidad:          especialidad          ?? this.especialidad,
      recursante:            recursante            ?? this.recursante,
      porcentajeAsistencia:  porcentajeAsistencia  ?? this.porcentajeAsistencia,
      academicYear:          academicYear          ?? this.academicYear,
      gradeYear:             gradeYear             ?? this.gradeYear,
      division:              division              ?? this.division,
      isActive:              isActive              ?? this.isActive,
      workshopGroupId: clearWorkshopGroupId ? null : (workshopGroupId ?? this.workshopGroupId),
      taller:                taller                ?? this.taller,
    );
  }
}

enum EstadoRegularidad { regular, irregular, enRiesgo }
