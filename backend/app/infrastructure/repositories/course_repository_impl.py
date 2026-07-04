from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.course import Course
from app.domain.repositories.course_repository import CourseRepository
from app.infrastructure.models.course_model import CourseModel, ShiftModel
from app.infrastructure.models.student_model import StudentCourseEnrollmentModel


class CourseRepositoryImpl(CourseRepository):
    """Reads the `courses` table joined to its four dimensions. `total_students`
    is the count of active enrollments (end_date IS NULL) for the course."""

    def __init__(self, db: Session):
        self.db = db

    def _total_students(self, course_id: str) -> int:
        return (
            self.db.query(StudentCourseEnrollmentModel)
            .filter(
                StudentCourseEnrollmentModel.course_id == course_id,
                StudentCourseEnrollmentModel.end_date.is_(None),
            )
            .count()
        )

    def _to_entity(self, c: CourseModel) -> Course:
        academic_year = c.academic_year.name
        division = c.division.name
        specialty = c.specialty.name
        shift = c.shift.name
        workshops = [wg.name for wg in c.workshop_groups]

        name = f"{academic_year} {division} — {specialty} — {shift}"
        if workshops:
            name = f"{name} ({', '.join(workshops)})"

        return Course(
            id=str(c.id),
            academic_year=academic_year,
            division=division,
            specialty=specialty,
            shift=shift,
            total_students=self._total_students(c.id),
            name=name,
            horario="",
            workshop_groups=workshops,
        )

    def get_courses(self) -> List[Course]:
        rows = self.db.query(CourseModel).filter(CourseModel.is_active == True).all()
        return [self._to_entity(c) for c in rows]

    def get_course_by_id(self, id: str) -> Optional[Course]:
        c = self.db.query(CourseModel).filter(CourseModel.id == id).first()
        return self._to_entity(c) if c else None

    def get_courses_by_shift(self, shift_name: str) -> List[Course]:
        rows = (
            self.db.query(CourseModel)
            .join(ShiftModel, CourseModel.shift_id == ShiftModel.id)
            .filter(ShiftModel.name == shift_name, CourseModel.is_active == True)
            .all()
        )
        return [self._to_entity(c) for c in rows]
