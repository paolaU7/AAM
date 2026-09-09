// Entities for the Dirección → "Configuración" section. Map the `/config/*`
// endpoints of the Go backend.
//
//   General  → ConfigSchoolSettings (alerts + lunch window), ShiftConfig
//              (editable label per shift), ShiftBreak (recreos).
//   Cursos   → CoursesStructure (years / divisions per year / workshop groups
//              per division + current academic year).
//   Dispositivos → EntryPoint, ReaderDevice, CreatedDevice.

class ConfigSchoolSettings {
  const ConfigSchoolSettings({
    required this.lunchStart,
    required this.lunchStartFifthModule,
    required this.lunchEnd,
    required this.consecutiveAbsencesAlertThreshold,
    required this.preceptorTempAssignmentAlertDays,
    required this.scheduleExceptionAlertDays,
  });

  final String lunchStart; // "HH:MM"
  final String lunchStartFifthModule;
  final String lunchEnd;
  final int consecutiveAbsencesAlertThreshold;
  final int preceptorTempAssignmentAlertDays;
  final int scheduleExceptionAlertDays;

  factory ConfigSchoolSettings.fromJson(Map<String, dynamic> json) => ConfigSchoolSettings(
        lunchStart: json['lunch_start'],
        lunchStartFifthModule: json['lunch_start_fifth_module'],
        lunchEnd: json['lunch_end'],
        consecutiveAbsencesAlertThreshold: (json['consecutive_absences_alert_threshold'] as num).toInt(),
        preceptorTempAssignmentAlertDays: (json['preceptor_temp_assignment_alert_days'] as num).toInt(),
        scheduleExceptionAlertDays: (json['schedule_exception_alert_days'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'lunch_start': lunchStart,
        'lunch_start_fifth_module': lunchStartFifthModule,
        'lunch_end': lunchEnd,
        'consecutive_absences_alert_threshold': consecutiveAbsencesAlertThreshold,
        'preceptor_temp_assignment_alert_days': preceptorTempAssignmentAlertDays,
        'schedule_exception_alert_days': scheduleExceptionAlertDays,
      };
}

/// Editable label of one shift. `shift` is the stable enum value.
class ShiftConfig {
  const ShiftConfig({required this.shift, required this.label});
  final String shift; // 'morning' | 'afternoon' | 'evening'
  final String label;

  factory ShiftConfig.fromJson(Map<String, dynamic> json) =>
      ShiftConfig(shift: json['shift'], label: json['label']);
}

/// One recess of a shift (school-wide). class_periods of type 'class' cannot
/// overlap one — the backend rejects that with a descriptive 400.
class ShiftBreak {
  const ShiftBreak({
    required this.id,
    required this.shift,
    required this.label,
    required this.startTime,
    required this.endTime,
  });
  final String id;
  final String shift;
  final String label;
  final String startTime; // "HH:MM"
  final String endTime;

  factory ShiftBreak.fromJson(Map<String, dynamic> json) => ShiftBreak(
        id: json['id'].toString(),
        shift: json['shift'],
        label: json['label'],
        startTime: json['start_time'],
        endTime: json['end_time'],
      );
}

/// One division inside a year of the structure tree.
class DivisionStructure {
  const DivisionStructure({required this.division, required this.workshopGroupCount});
  final int division;
  final int workshopGroupCount;

  factory DivisionStructure.fromJson(Map<String, dynamic> json) => DivisionStructure(
        division: (json['division'] as num).toInt(),
        workshopGroupCount: (json['workshop_group_count'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'division': division, 'workshop_group_count': workshopGroupCount};

  DivisionStructure copyWith({int? workshopGroupCount}) => DivisionStructure(
        division: division,
        workshopGroupCount: workshopGroupCount ?? this.workshopGroupCount,
      );
}

/// One year of the structure tree.
class YearStructure {
  const YearStructure({
    required this.gradeYear,
    required this.divisionCount,
    required this.divisions,
  });
  final int gradeYear;
  final int divisionCount;
  final List<DivisionStructure> divisions;

  factory YearStructure.fromJson(Map<String, dynamic> json) => YearStructure(
        gradeYear: (json['grade_year'] as num).toInt(),
        divisionCount: (json['division_count'] as num).toInt(),
        divisions: ((json['divisions'] as List?) ?? const [])
            .map((e) => DivisionStructure.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'grade_year': gradeYear,
        'division_count': divisionCount,
        'divisions': divisions.map((d) => d.toJson()).toList(),
      };

  YearStructure copyWith({int? divisionCount, List<DivisionStructure>? divisions}) => YearStructure(
        gradeYear: gradeYear,
        divisionCount: divisionCount ?? this.divisionCount,
        divisions: divisions ?? this.divisions,
      );
}

/// The whole Configuración → Cursos payload.
class CoursesStructure {
  const CoursesStructure({
    required this.currentAcademicYear,
    required this.maxGradeYear,
    required this.years,
  });
  final int currentAcademicYear;
  final int maxGradeYear;
  final List<YearStructure> years;

  factory CoursesStructure.fromJson(Map<String, dynamic> json) => CoursesStructure(
        currentAcademicYear: (json['current_academic_year'] as num).toInt(),
        maxGradeYear: (json['max_grade_year'] as num).toInt(),
        years: ((json['years'] as List?) ?? const [])
            .map((e) => YearStructure.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'current_academic_year': currentAcademicYear,
        'max_grade_year': maxGradeYear,
        'years': years.map((y) => y.toJson()).toList(),
      };

  CoursesStructure copyWith({int? currentAcademicYear, int? maxGradeYear, List<YearStructure>? years}) =>
      CoursesStructure(
        currentAcademicYear: currentAcademicYear ?? this.currentAcademicYear,
        maxGradeYear: maxGradeYear ?? this.maxGradeYear,
        years: years ?? this.years,
      );
}

// ── Dispositivos ──────────────────────────────────────────────────────────

class EntryPoint {
  const EntryPoint({required this.id, required this.name, this.location, required this.createdAt});
  final String id;
  final String name;
  final String? location;
  final DateTime createdAt;

  factory EntryPoint.fromJson(Map<String, dynamic> json) => EntryPoint(
        id: json['id'].toString(),
        name: json['name'],
        location: json['location'],
        createdAt: DateTime.parse(json['created_at']),
      );
}

class ReaderDevice {
  const ReaderDevice({
    required this.id,
    required this.entryPointId,
    required this.entryPointName,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.revokedAt,
  });
  final String id;
  final String entryPointId;
  final String entryPointName;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null || !isActive;

  factory ReaderDevice.fromJson(Map<String, dynamic> json) => ReaderDevice(
        id: json['id'].toString(),
        entryPointId: json['entry_point_id'].toString(),
        entryPointName: json['entry_point_name'] ?? '',
        name: json['name'],
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']),
        revokedAt: json['revoked_at'] != null ? DateTime.parse(json['revoked_at']) : null,
      );
}

class CreatedDevice {
  const CreatedDevice({required this.device, required this.apiKey});
  final ReaderDevice device;
  final String apiKey;

  factory CreatedDevice.fromJson(Map<String, dynamic> json) => CreatedDevice(
        device: ReaderDevice.fromJson(json),
        apiKey: json['api_key'],
      );
}
