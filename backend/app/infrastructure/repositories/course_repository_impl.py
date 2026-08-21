from typing import List, Optional
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.domain.entities.course import Course
from app.domain.repositories.course_repository import CourseRepository
from app.infrastructure.models.course_model import CourseModel
from app.infrastructure.models.student_model import StudentModel

_GRADE_YEAR_ORDINALS = {1: "1ro", 2: "2do", 3: "3ro", 4: "4to", 5: "5to", 6: "6to", 7: "7mo"}
_DIVISION_ORDINALS = {
    1: "1ra", 2: "2da", 3: "3ra", 4: "4ta", 5: "5ta",
    6: "6ta", 7: "7ma", 8: "8va", 9: "9na", 10: "10ma",
}


def _grade_year_ordinal(grade_year: int) -> str:
    return _GRADE_YEAR_ORDINALS.get(grade_year, f"{grade_year}to")


def _division_ordinal(division: int) -> str:
    return _DIVISION_ORDINALS.get(division, f"{division}ra")


class CourseRepositoryImpl(CourseRepository):

    def __init__(self, db: Session):
        self.db = db

    def _to_entity(self, model: CourseModel, total_students: int) -> Course:
        name = f"{_grade_year_ordinal(model.grade_year)} {_division_ordinal(model.division)} ({model.academic_year})"
        return Course(
            id=str(model.id),
            academic_year=model.academic_year,
            grade_year=model.grade_year,
            division=model.division,
            specialty=model.specialty,
            total_students=total_students,
            name=name,
        )

    def _student_counts(self) -> dict:
        rows = (
            self.db.query(StudentModel.course_id, func.count(StudentModel.id))
            .group_by(StudentModel.course_id)
            .all()
        )
        return {course_id: count for course_id, count in rows}

    def get_courses(self) -> List[Course]:
        counts = self._student_counts()
        rows = self.db.query(CourseModel).all()
        return [self._to_entity(c, counts.get(c.id, 0)) for c in rows]

    def get_course_by_id(self, id: str) -> Optional[Course]:
        model = self.db.query(CourseModel).filter(CourseModel.id == id).first()
        if model is None:
            return None
        total = self.db.query(StudentModel).filter(StudentModel.course_id == id).count()
        return self._to_entity(model, total)

    def resolve_course(self, academic_year: int, grade_year: int, division: int) -> Optional[Course]:
        model = (
            self.db.query(CourseModel)
            .filter(
                CourseModel.academic_year == academic_year,
                CourseModel.grade_year == grade_year,
                CourseModel.division == division,
            )
            .first()
        )
        if model is None:
            return None
        total = self.db.query(StudentModel).filter(StudentModel.course_id == model.id).count()
        return self._to_entity(model, total)

    def create_course(
        self, academic_year: int, grade_year: int, division: int, specialty: Optional[str] = None,
    ) -> Course:
        model = CourseModel(
            academic_year=academic_year, grade_year=grade_year, division=division,
            specialty=specialty,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model, 0)
