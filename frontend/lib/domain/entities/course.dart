/// Domain entity: Course
///
/// Reflects the new DB schema: a course is the combination of the four
/// independent dimensions (academic year, division, specialty, shift).
/// Workshop groups are no longer part of the course itself: they're a
/// separate many-to-many relation (`workshopGroups`).
class Course {
  const Course({
    required this.id,
    required this.academicYear,
    required this.division,
    required this.specialty,
    required this.shift,
    this.workshopGroups = const [],
    required this.totalStudents,
    this.preceptorId,
    String? name,
    String? schedule,
  })  : _name = name,
        _schedule = schedule;

  final String id;
  final String academicYear;         // academic year name, e.g. "4"
  final String division;             // "A", "B", "C"...
  final String specialty;
  final String shift;                // "Morning" | "Afternoon" | "Evening"
  final List<String> workshopGroups; // workshop groups (N:M), e.g. ["Robotics"]
  final int totalStudents;
  final String? preceptorId;

  // Provided by the backend (CourseResponse). Derived if missing.
  final String? _name;
  final String? _schedule;

  String get name =>
      _name ?? '$academicYear° $division° — $specialty — $shift';

  String get schedule => _schedule ?? '';

  /// Compat: workshop groups joined as a single string.
  String get workshopGroupLabel => workshopGroups.join(', ');

  Course copyWith({
    String? id,
    String? academicYear,
    String? division,
    String? specialty,
    String? shift,
    List<String>? workshopGroups,
    int? totalStudents,
    String? preceptorId,
    String? name,
    String? schedule,
  }) {
    return Course(
      id:             id             ?? this.id,
      academicYear:   academicYear   ?? this.academicYear,
      division:       division       ?? this.division,
      specialty:      specialty      ?? this.specialty,
      shift:          shift          ?? this.shift,
      workshopGroups: workshopGroups ?? this.workshopGroups,
      totalStudents:  totalStudents  ?? this.totalStudents,
      preceptorId:    preceptorId    ?? this.preceptorId,
      name:           name           ?? _name,
      schedule:       schedule       ?? _schedule,
    );
  }
}