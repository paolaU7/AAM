import '../entities/course.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/course_repository.dart';

/// Use case: fetch all the data the Dashboard needs
class GetDashboardSummary {
  const GetDashboardSummary({
    required this.attendanceRepository,
    required this.courseRepository,
  });

  final AttendanceRepository attendanceRepository;
  final CourseRepository courseRepository;

  Future<DashboardSummary> call(DateTime date) async {
    final globalSummary   = await attendanceRepository.getDailySummary(date);
    final morningSummary  = await attendanceRepository.getSummaryByShift('morning',   date);
    final afternoonSummary = await attendanceRepository.getSummaryByShift('afternoon', date);
    final eveningSummary  = await attendanceRepository.getSummaryByShift('evening',   date);
    final courses         = await courseRepository.getCourses();

    return DashboardSummary(
      globalSummary:    globalSummary,
      morningSummary:   morningSummary,
      afternoonSummary: afternoonSummary,
      eveningSummary:   eveningSummary,
      courses:          courses,
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.globalSummary,
    required this.morningSummary,
    required this.afternoonSummary,
    required this.eveningSummary,
    required this.courses,
  });

  final AttendanceSummary globalSummary;
  final AttendanceSummary morningSummary;
  final AttendanceSummary afternoonSummary;
  final AttendanceSummary eveningSummary;
  final List<Course> courses;
}