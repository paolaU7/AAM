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

  Future<AttendanceRecord> registerManualCheckIn({
    required String studentId,
    required String courseId,
    required DateTime checkInTime,
  });

  Future<AttendanceRecord> registerEarlyDeparture({
    required String recordId,
    required DateTime departureTime,
    required String reason,
  });

  Future<AttendanceRecord> markNonComputable({
    required String recordId,
    required String reason,
  });
}