from typing import List, Optional
from app.domain.entities.course import Course
from app.domain.repositories.course_repository import CourseRepository


class CourseError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class GetCourses:
    def __init__(self, repo: CourseRepository):
        self.repo = repo

    def execute(self) -> List[Course]:
        return self.repo.get_courses()


class GetCourseById:
    def __init__(self, repo: CourseRepository):
        self.repo = repo

    def execute(self, id: str) -> Optional[Course]:
        return self.repo.get_course_by_id(id)


class CreateCourse:
    def __init__(self, repo: CourseRepository):
        self.repo = repo

    def execute(
        self, *, academic_year: int, grade_year: int, division: int, specialty: Optional[str] = None,
    ) -> Course:
        if grade_year < 1 or grade_year > 7:
            raise CourseError("El año de cursada debe estar entre 1 y 7.", 400)
        if division < 1:
            raise CourseError("La división debe ser mayor a 0.", 400)
        if self.repo.resolve_course(academic_year, grade_year, division) is not None:
            raise CourseError("Ya existe un curso con ese año lectivo, año de cursada y división.", 409)

        specialty = (specialty or "").strip() or None
        return self.repo.create_course(
            academic_year=academic_year, grade_year=grade_year, division=division, specialty=specialty,
        )
