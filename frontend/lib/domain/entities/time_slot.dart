/// Domain entity: TimeSlot
///
/// Franja horaria semanal recurrente de un curso o de un taller. Exactamente
/// uno de `courseId` / `workshopGroupId` está seteado, según `activityType`
/// (impuesto por CHECK en la DB, no repetido acá como validación porque el
/// dato ya viene resuelto del backend).
class TimeSlot {
  const TimeSlot({
    required this.id,
    this.courseId,
    this.workshopGroupId,
    required this.shift,
    required this.activityType,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.lateToleranceMinutes = 0,
  });

  final String id;
  final String? courseId;         // requerido si activityType es main_shift/after_shift
  final String? workshopGroupId;  // requerido si activityType es workshop
  final ShiftType shift;
  final ActivityType activityType;
  final int dayOfWeek;            // ISO: 1=lunes .. 7=domingo
  final ClockTime startTime;
  final ClockTime endTime;
  final int lateToleranceMinutes;

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        id: json['id'].toString(),
        courseId: json['course_id']?.toString(),
        workshopGroupId: json['workshop_group_id']?.toString(),
        shift: shiftTypeFromString(json['shift'] as String),
        activityType: activityTypeFromString(json['activity_type'] as String),
        dayOfWeek: (json['day_of_week'] as num).toInt(),
        startTime: ClockTime.parse(json['start_time'] as String),
        endTime: ClockTime.parse(json['end_time'] as String),
        lateToleranceMinutes: (json['late_tolerance_minutes'] as num?)?.toInt() ?? 0,
      );
}

/// `shift_type` enum de la DB.
enum ShiftType { morning, afternoon, evening }

ShiftType shiftTypeFromString(String raw) => switch (raw) {
      'morning' => ShiftType.morning,
      'afternoon' => ShiftType.afternoon,
      'evening' => ShiftType.evening,
      _ => throw FormatException('shift_type desconocido: $raw'),
    };

String shiftTypeToJson(ShiftType s) => switch (s) {
      ShiftType.morning => 'morning',
      ShiftType.afternoon => 'afternoon',
      ShiftType.evening => 'evening',
    };

String shiftTypeLabel(ShiftType s) => switch (s) {
      ShiftType.morning => 'Mañana',
      ShiftType.afternoon => 'Tarde',
      ShiftType.evening => 'Noche',
    };

/// `activity_type` enum de la DB.
enum ActivityType { mainShift, workshop, afterShift }

ActivityType activityTypeFromString(String raw) => switch (raw) {
      'main_shift' => ActivityType.mainShift,
      'workshop' => ActivityType.workshop,
      'after_shift' => ActivityType.afterShift,
      _ => throw FormatException('activity_type desconocido: $raw'),
    };

String activityTypeToJson(ActivityType t) => switch (t) {
      ActivityType.mainShift => 'main_shift',
      ActivityType.workshop => 'workshop',
      ActivityType.afterShift => 'after_shift',
    };

/// Etiqueta legible del tipo de actividad (no hay concepto de "materia" en
/// el schema — `time_slots` no tiene una columna para eso).
String activityTypeLabel(ActivityType t) => switch (t) {
      ActivityType.mainShift => 'Curricular',
      ActivityType.workshop => 'Taller',
      ActivityType.afterShift => 'Contraturno',
    };

/// Hora del día sin dependencias externas (sin Flutter) — se usa en vez de
/// `TimeOfDay` para mantener el dominio libre de la capa de presentación.
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  factory ClockTime.parse(String raw) {
    final parts = raw.split(':');
    return ClockTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Formato que espera el backend para un campo TIME ("HH:mm:00").
  String toJson() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';

  @override
  int compareTo(ClockTime other) => minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is ClockTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
