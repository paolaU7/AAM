import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/time_slot_repository.dart';
import '../datasources/api_datasource.dart';

class TimeSlotRepositoryImpl implements TimeSlotRepository {
  TimeSlotRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;

  @override
  Future<List<TimeSlot>> getTimeSlotsByCourse(String courseId) =>
      _datasource.getTimeSlotsByCourse(courseId);

  @override
  Future<List<TimeSlot>> getTimeSlotsByWorkshopGroup(String workshopGroupId) =>
      _datasource.getTimeSlotsByWorkshopGroup(workshopGroupId);
}
