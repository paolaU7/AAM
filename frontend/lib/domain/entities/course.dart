/// Domain entity: Course
///
/// Reflects the current DB schema: a course is the combination of three
/// independent numeric dimensions — academic year (calendar year), grade
/// year (1..7, "1ro".."7mo") and division (1, 2, 3..., "1ra", "2da"...) —
/// unique as a triple. The readable label ("1ro 2da (2026)") is not stored
/// in the DB; it's derived here from those three numbers.
class Course {
  const Course({
    required this.id,
    required this.academicYear,
    required this.gradeYear,
    required this.division,
    this.specialty,
    this.totalStudents = 0,
    String? name,
    String? schedule,
  })  : _name = name,
        _schedule = schedule;

  final String id;
  final int academicYear;   // calendar year, e.g. 2026
  final int gradeYear;      // 1..7 ("1ro".."7mo")
  final int division;       // 1, 2, 3... ("1ra", "2da"...)
  final String? specialty;  // nullable — el ciclo básico no tiene especialidad
  final int totalStudents;

  // Provided by the backend if it already computes a label; derived otherwise.
  final String? _name;
  final String? _schedule;

  String get name =>
      _name ?? '${gradeYearOrdinal(gradeYear)} ${divisionOrdinal(division)} ($academicYear)';

  /// Not part of the DB schema (no single "schedule" column on `courses`;
  /// that lives in `time_slots`). Kept as a display-only override so screens
  /// that show a schedule summary can still render something if the backend
  /// provides one.
  String get schedule => _schedule ?? '';

  Course copyWith({
    String? id,
    int? academicYear,
    int? gradeYear,
    int? division,
    String? specialty,
    int? totalStudents,
    String? name,
    String? schedule,
  }) {
    return Course(
      id:            id            ?? this.id,
      academicYear:  academicYear  ?? this.academicYear,
      gradeYear:     gradeYear     ?? this.gradeYear,
      division:      division      ?? this.division,
      specialty:     specialty     ?? this.specialty,
      totalStudents: totalStudents ?? this.totalStudents,
      name:          name          ?? _name,
      schedule:      schedule      ?? _schedule,
    );
  }
}

/// "1ro", "2do", "3ro", "4to", "5to", "6to", "7mo" — matches the
/// `grade_year` CHECK (1..7) in `courses`.
String gradeYearOrdinal(int gradeYear) {
  const labels = {1: '1ro', 2: '2do', 3: '3ro', 4: '4to', 5: '5to', 6: '6to', 7: '7mo'};
  return labels[gradeYear] ?? '${gradeYear}to';
}

/// "1ra", "2da", "3ra"... — `division` has no upper bound in the schema
/// (CHECK > 0 only), so anything past the common cases falls back to "Nra".
String divisionOrdinal(int division) {
  const labels = {
    1: '1ra', 2: '2da', 3: '3ra', 4: '4ta', 5: '5ta',
    6: '6ta', 7: '7ma', 8: '8va', 9: '9na', 10: '10ma',
  };
  return labels[division] ?? '${division}ra';
}
