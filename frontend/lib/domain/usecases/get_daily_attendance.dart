import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class GetDailyAttendance {
  const GetDailyAttendance(this.repository);
  final AttendanceRepository repository;

  Future<List<AttendanceRecord>> call({
    required String courseId,
    required DateTime date,
  }) {
    return repository.getRecordsByCourseAndDate(courseId, date);
  }
}

class RegisterManualCheckIn {
  const RegisterManualCheckIn(this.repository);
  final AttendanceRepository repository;

  Future<AttendanceRecord> call({
    required String studentId,
    required String courseId,
    required DateTime entryTimestamp,
    required AttendanceStatus status,
  }) {
    return repository.registerManualCheckIn(
      studentId: studentId,
      courseId: courseId,
      entryTimestamp: entryTimestamp,
      status: status,
    );
  }
}

class RegisterEarlyDeparture {
  const RegisterEarlyDeparture(this.repository);
  final AttendanceRepository repository;

  Future<AttendanceRecord> call({
    required String recordId,
    required DateTime departureTime,
    required String reason,
    required String registeredByUserId,
  }) {
    return repository.registerEarlyDeparture(
      recordId: recordId,
      departureTime: departureTime,
      reason: reason,
      registeredByUserId: registeredByUserId,
    );
  }
}
