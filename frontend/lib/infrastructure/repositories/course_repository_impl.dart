import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/mock_datasource.dart';
import '../datasources/api_datasource.dart';

class CourseRepositoryImpl implements CourseRepository {
  CourseRepositoryImpl(ApiDatasource datasource);
  final MockDatasource _mock = MockDatasource();

  @override
  Future<List<Course>> getCourses() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _mock.getCursos();
  }

  @override
  Future<List<Course>> getCoursesByShift(String shift) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final all = await getCourses();
    return all.where((c) => c.shift == shift).toList();
  }

  @override
  Future<Course?> getCourseById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final all = await getCourses();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
