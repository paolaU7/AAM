import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/mock_datasource.dart';
import '../datasources/api_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(ApiDatasource datasource);
  final MockDatasource _mock = MockDatasource();

  @override
  Future<List<AttendanceRecord>> getRecordsByCourseAndDate(
    String courseId,
    DateTime date,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mock.getRegistros(courseId, date);
  }

  @override
  Future<AttendanceSummary> getDailySummary(DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mock.getResumenGlobal(date);
  }

  @override
  Future<AttendanceSummary> getSummaryByShift(
    String shift,
    DateTime date,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _mock.getResumenTurno(shift, date);
  }

  @override
  Future<AttendanceRecord> registerManualCheckIn({
    required String studentId,
    required String courseId,
    required DateTime checkInTime,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return AttendanceRecord(
      id:          'mock_${DateTime.now().millisecondsSinceEpoch}',
      studentId:   studentId,
      studentName: 'Alumno Manual',
      courseId:    courseId,
      date:        DateTime(checkInTime.year, checkInTime.month, checkInTime.day),
      checkInTime: checkInTime,
      source:      AttendanceSource.manual,
      status:      AttendanceStatus.present,
    );
  }

  @override
  Future<AttendanceRecord> registerEarlyDeparture({
    required String recordId,
    required DateTime departureTime,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return AttendanceRecord(
      id:              recordId,
      studentId:       '',
      studentName:     '',
      courseId:        '',
      date:            DateTime.now(),
      checkInTime:     null,
      source:          AttendanceSource.unknown,
      status:          AttendanceStatus.present,
      departureTime:   departureTime,
      departureReason: reason,
    );
  }

  @override
  Future<AttendanceRecord> markNonComputable({
    required String recordId,
    required String reason,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return AttendanceRecord(
      id:                  recordId,
      studentId:           '',
      studentName:         '',
      courseId:            '',
      date:                DateTime.now(),
      checkInTime:         null,
      source:              AttendanceSource.unknown,
      status:              AttendanceStatus.nonComputable,
      isNonComputable:     true,
      nonComputableReason: reason,
    );
  }
}