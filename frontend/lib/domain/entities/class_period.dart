import 'time_slot.dart' show ShiftType, shiftTypeFromString, ClockTime;

/// 'class' | 'recess' | 'lunch'
enum PeriodType { lesson, recess, lunch }

PeriodType periodTypeFromString(String raw) => switch (raw) {
      'class' => PeriodType.lesson,
      'recess' => PeriodType.recess,
      'lunch' => PeriodType.lunch,
      _ => throw FormatException('period_type desconocido: $raw'),
    };

String periodTypeToJson(PeriodType t) => switch (t) {
      PeriodType.lesson => 'class',
      PeriodType.recess => 'recess',
      PeriodType.lunch => 'lunch',
    };

String periodTypeLabel(PeriodType t) => switch (t) {
      PeriodType.lesson => 'Clase',
      PeriodType.recess => 'Recreo',
      PeriodType.lunch => 'Almuerzo',
    };

/// Un período del horario académico DETALLADO día por día de un curso —
/// distinto de TimeSlot (que solo abre/cierra el turno de asistencia).
class ClassPeriod {
  const ClassPeriod({
    required this.id,
    required this.courseId,
    required this.dayOfWeek,
    required this.shift,
    required this.periodOrder,
    required this.periodType,
    required this.startTime,
    required this.endTime,
    this.isFifthModule = false,
    this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
  });

  final String id;
  final String courseId;
  final int dayOfWeek; // ISO 1..7
  final ShiftType shift;
  final int periodOrder;
  final PeriodType periodType;
  final ClockTime startTime;
  final ClockTime endTime;
  final bool isFifthModule;
  final String? subjectId;
  final String? subjectName;
  final String? teacherId;
  final String? teacherName;

  factory ClassPeriod.fromJson(Map<String, dynamic> json) => ClassPeriod(
        id: json['id'].toString(),
        courseId: json['course_id'].toString(),
        dayOfWeek: (json['day_of_week'] as num).toInt(),
        shift: shiftTypeFromString(json['shift']),
        periodOrder: (json['period_order'] as num).toInt(),
        periodType: periodTypeFromString(json['period_type']),
        startTime: ClockTime.parse(json['start_time']),
        endTime: ClockTime.parse(json['end_time']),
        isFifthModule: json['is_fifth_module'] ?? false,
        subjectId: json['subject_id']?.toString(),
        subjectName: json['subject_name'],
        teacherId: json['teacher_id']?.toString(),
        teacherName: json['teacher_name'],
      );
}
