import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/api_datasource.dart';

class CourseRepositoryImpl implements CourseRepository {
  CourseRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;

  @override
  Future<List<Course>> getCourses() => _datasource.getCursos();

  @override
  Future<Course?> getCourseById(String id) async {
    final all = await getCourses();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
