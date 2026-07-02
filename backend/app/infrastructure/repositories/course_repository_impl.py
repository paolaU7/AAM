from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.course import Course
from app.domain.repositories.course_repository import CourseRepository
from app.infrastructure.models.course_model import CourseModel, ShiftModel

class CourseRepositoryImpl(CourseRepository):

    def __init__(self, db: Session):
        self.db = db

    def _to_entity(self, model: CourseModel) -> Course:
        return Course(
            id=model.id,
            academic_year_id=str(model.academic_year_id),
            academic_year=model.academic_year.name,
            division_id=str(model.division_id),
            division=model.division.name,
            specialty_id=str(model.specialty_id),
            specialty=model.specialty.name,
            shift_id=str(model.shift_id),
            shift=model.shift.name,
            shift_start_time=model.shift.start_time.isoformat() if model.shift else None,
            shift_end_time=model.shift.end_time.isoformat() if model.shift else None,
            workshop_groups=[wg.name for wg in model.workshop_groups],
            is_active=model.is_active,
            total_students=0,
            created_at=model.created_at,
        )

    def get_courses(self) -> List[Course]:
        rows = self.db.query(CourseModel).filter(CourseModel.is_active == True).all()
        return [self._to_entity(r) for r in rows]

    def get_course_by_id(self, id: str) -> Optional[Course]:
        row = self.db.query(CourseModel).filter(CourseModel.id == id).first()
        return self._to_entity(row) if row else None

    def get_courses_by_shift(self, shift_name: str) -> List[Course]:
        rows = self.db.query(CourseModel).join(ShiftModel).filter(
            ShiftModel.name == shift_name,
            CourseModel.is_active == True
        ).all()
        return [self._to_entity(r) for r in rows]
