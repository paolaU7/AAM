from datetime import date
from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.preceptor_assignment import CoursePreceptor, CoursePreceptorTempAssignment
from app.domain.repositories.preceptor_assignment_repository import (
    CoursePreceptorRepository, CoursePreceptorTempAssignmentRepository,
)
from app.infrastructure.models.preceptor_model import CoursePreceptorModel, CoursePreceptorTempAssignmentModel
from app.infrastructure.models.schedule_model import ShiftTypeEnum


class CoursePreceptorRepositoryImpl(CoursePreceptorRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: CoursePreceptorModel) -> CoursePreceptor:
        return CoursePreceptor(
            course_id=str(m.course_id), shift=m.shift.value,
            preceptor_id=str(m.preceptor_id), preceptor_name=m.preceptor.full_name,
        )

    def get_by_course(self, course_id: str) -> List[CoursePreceptor]:
        rows = self.db.query(CoursePreceptorModel).filter(CoursePreceptorModel.course_id == course_id).all()
        return [self._to_entity(r) for r in rows]

    def assign(self, course_id: str, shift: str, preceptor_id: str) -> CoursePreceptor:
        shift_enum = ShiftTypeEnum(shift)
        existing = (
            self.db.query(CoursePreceptorModel)
            .filter(CoursePreceptorModel.course_id == course_id, CoursePreceptorModel.shift == shift_enum)
            .first()
        )
        if existing is not None:
            existing.preceptor_id = preceptor_id
            self.db.commit()
            self.db.refresh(existing)
            return self._to_entity(existing)

        model = CoursePreceptorModel(course_id=course_id, shift=shift_enum, preceptor_id=preceptor_id)
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)

    def remove(self, course_id: str, shift: str) -> bool:
        existing = (
            self.db.query(CoursePreceptorModel)
            .filter(CoursePreceptorModel.course_id == course_id, CoursePreceptorModel.shift == ShiftTypeEnum(shift))
            .first()
        )
        if existing is None:
            return False
        self.db.delete(existing)
        self.db.commit()
        return True


class CoursePreceptorTempAssignmentRepositoryImpl(CoursePreceptorTempAssignmentRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: CoursePreceptorTempAssignmentModel) -> CoursePreceptorTempAssignment:
        return CoursePreceptorTempAssignment(
            id=str(m.id), course_id=str(m.course_id), shift=m.shift.value,
            preceptor_id=str(m.preceptor_id), preceptor_name=m.preceptor.full_name,
            start_date=m.start_date, end_date=m.end_date, reason=m.reason,
        )

    def get_by_course(self, course_id: str) -> List[CoursePreceptorTempAssignment]:
        rows = (
            self.db.query(CoursePreceptorTempAssignmentModel)
            .filter(CoursePreceptorTempAssignmentModel.course_id == course_id)
            .order_by(CoursePreceptorTempAssignmentModel.start_date.desc())
            .all()
        )
        return [self._to_entity(r) for r in rows]

    def create(
        self, *, course_id: str, shift: str, preceptor_id: str,
        start_date: date, end_date: date, reason: Optional[str], created_by: str,
    ) -> CoursePreceptorTempAssignment:
        model = CoursePreceptorTempAssignmentModel(
            course_id=course_id, shift=ShiftTypeEnum(shift), preceptor_id=preceptor_id,
            start_date=start_date, end_date=end_date, reason=reason, created_by=created_by,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)

    def delete(self, id: str) -> bool:
        model = self.db.query(CoursePreceptorTempAssignmentModel).filter(
            CoursePreceptorTempAssignmentModel.id == id
        ).first()
        if model is None:
            return False
        self.db.delete(model)
        self.db.commit()
        return True
