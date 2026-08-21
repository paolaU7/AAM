import '../entities/attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> getRecordsByCourseAndDate(
    String courseId,
    DateTime date,
  );

  Future<AttendanceSummary> getDailySummary(DateTime date);

  Future<AttendanceSummary> getSummaryByShift(
    String shift,
    DateTime date,
  );

  /// El estado lo elige el preceptor al cargar — no hay time_slot asociado
  /// para inferir tardanza automáticamente en una carga manual.
  Future<AttendanceRecord> registerManualCheckIn({
    required String studentId,
    required String courseId,
    required DateTime entryTimestamp,
    required AttendanceStatus status,
  });

  /// `registeredByUserId` es obligatorio: `early_departures.registered_by`
  /// no admite NULL en el schema real.
  Future<AttendanceRecord> registerEarlyDeparture({
    required String recordId,
    required DateTime departureTime,
    required String reason,
    required String registeredByUserId,
  });

  Future<AttendanceRecord> markNonComputable(String recordId);
}
