from typing import List, Optional
from app.domain.entities.course import Course
from app.domain.repositories.course_repository import CourseRepository


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


class GetCoursesByShift:
    def __init__(self, repo: CourseRepository):
        self.repo = repo

    def execute(self, shift_name: str) -> List[Course]:
        return self.repo.get_courses_by_shift(shift_name)
