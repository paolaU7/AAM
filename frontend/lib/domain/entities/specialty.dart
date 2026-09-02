/// Domain entity: Specialty
///
/// Catálogo de especialidades (Programación, Construcciones, Electrónica,
/// Ciclo Básico). "Ciclo Básico" es la única con `isBasicCycle == true` —
/// nunca se elige a mano, se asigna sola a cursos de 1ro a 3ro.
class Specialty {
  const Specialty({required this.id, required this.name, required this.isBasicCycle});

  final String id;
  final String name;
  final bool isBasicCycle;

  factory Specialty.fromJson(Map<String, dynamic> json) => Specialty(
        id: json['id'].toString(),
        name: json['name'],
        isBasicCycle: json['is_basic_cycle'] ?? false,
      );
}

/// Domain entity: SchoolSettings
///
/// Fila única de configuración general — techo de año de cursada y de
/// división que se ofrecen en los desplegables de alta de curso.
class SchoolSettings {
  const SchoolSettings({required this.maxGradeYear, required this.maxDivision});

  final int maxGradeYear;
  final int maxDivision;

  factory SchoolSettings.fromJson(Map<String, dynamic> json) => SchoolSettings(
        maxGradeYear: (json['max_grade_year'] as num).toInt(),
        maxDivision: (json['max_division'] as num).toInt(),
      );
}
