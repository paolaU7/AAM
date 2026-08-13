import '../entities/time_slot.dart';

abstract class TimeSlotRepository {
  /// Franjas de un curso (main_shift + after_shift comparten `course_id`).
  Future<List<TimeSlot>> getTimeSlotsByCourse(String courseId);

  /// Franjas de un grupo de taller (activity_type = workshop).
  Future<List<TimeSlot>> getTimeSlotsByWorkshopGroup(String workshopGroupId);
}
