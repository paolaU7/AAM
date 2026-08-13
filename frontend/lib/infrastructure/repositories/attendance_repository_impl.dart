import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/api_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;

  @override
  Future<List<AttendanceRecord>> getRecordsByCourseAndDate(
    String courseId,
    DateTime date,
  ) =>
      _datasource.getRegistros(courseId, date);

  @override
  Future<AttendanceSummary> getDailySummary(DateTime date) =>
      _datasource.getResumen(date);

  @override
  Future<AttendanceSummary> getSummaryByShift(
    String shift,
    DateTime date,
  ) =>
      _datasource.getResumen(date, shift: shift);

  @override
  Future<AttendanceRecord> registerManualCheckIn({
    required String studentId,
    required String courseId,
    required DateTime entryTimestamp,
    required AttendanceStatus status,
  }) =>
      _datasource.registrarIngresoManual(
        studentId: studentId,
        courseId: courseId,
        entryTimestamp: entryTimestamp,
        status: status,
      );

  @override
  Future<AttendanceRecord> registerEarlyDeparture({
    required String recordId,
    required DateTime departureTime,
    required String reason,
    required String registeredByUserId,
  }) =>
      _datasource.registrarRetiroAnticipado(
        recordId: recordId,
        departureTime: departureTime,
        reason: reason,
        registeredByUserId: registeredByUserId,
      );

  @override
  Future<AttendanceRecord> markNonComputable(String recordId) =>
      _datasource.marcarNoComputable(recordId);
}
