import '../entities/course.dart';

abstract class CourseRepository {
  Future<List<Course>> getCourses();
  Future<List<Course>> getCoursesByShift(String shift);
  Future<Course?> getCourseById(String id);
}