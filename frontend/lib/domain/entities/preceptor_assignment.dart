import 'time_slot.dart' show ShiftType, shiftTypeFromString;

/// Preceptor a cargo PERMANENTE de un curso, por turno, durante todo el año
/// lectivo. Un curso puede tener un preceptor distinto por turno.
class CoursePreceptor {
  const CoursePreceptor({
    required this.courseId,
    required this.shift,
    required this.preceptorId,
    required this.preceptorName,
  });

  final String courseId;
  final ShiftType shift;
  final String preceptorId;
  final String preceptorName;

  factory CoursePreceptor.fromJson(Map<String, dynamic> json) => CoursePreceptor(
        courseId: json['course_id'].toString(),
        shift: shiftTypeFromString(json['shift']),
        preceptorId: json['preceptor_id'].toString(),
        preceptorName: json['preceptor_name'],
      );
}

/// Reemplazo TEMPORAL (ej. licencia), con rango de fechas — máximo 1 mes,
/// impuesto por CHECK en la base.
class CoursePreceptorTempAssignment {
  const CoursePreceptorTempAssignment({
    required this.id,
    required this.courseId,
    required this.shift,
    required this.preceptorId,
    required this.preceptorName,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  final String id;
  final String courseId;
  final ShiftType shift;
  final String preceptorId;
  final String preceptorName;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;

  factory CoursePreceptorTempAssignment.fromJson(Map<String, dynamic> json) => CoursePreceptorTempAssignment(
        id: json['id'].toString(),
        courseId: json['course_id'].toString(),
        shift: shiftTypeFromString(json['shift']),
        preceptorId: json['preceptor_id'].toString(),
        preceptorName: json['preceptor_name'],
        startDate: DateTime.parse(json['start_date']),
        endDate: DateTime.parse(json['end_date']),
        reason: json['reason'],
      );
}

/// Replica `(d + 1 month)` de Postgres para dar feedback inmediato en la UI
/// (mismo día del mes siguiente, recortado al último día válido).
DateTime addOneCalendarMonth(DateTime d) {
  final year = d.year + (d.month ~/ 12);
  final month = d.month % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = d.day > lastDay ? lastDay : d.day;
  return DateTime(year, month, day);
}
