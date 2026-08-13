from datetime import time
from typing import List, Optional
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.domain.entities.class_period import ClassPeriod
from app.domain.repositories.class_period_repository import ClassPeriodRepository
from app.infrastructure.models.academic_model import ClassPeriodModel, PeriodTypeEnum
from app.infrastructure.models.schedule_model import ShiftTypeEnum


class ClassPeriodRepositoryImpl(ClassPeriodRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: ClassPeriodModel) -> ClassPeriod:
        return ClassPeriod(
            id=str(m.id),
            course_id=str(m.course_id),
            day_of_week=m.day_of_week,
            shift=m.shift.value,
            period_order=m.period_order,
            period_type=m.period_type.value,
            start_time=m.start_time,
            end_time=m.end_time,
            is_fifth_module=m.is_fifth_module,
            subject_id=str(m.subject_id) if m.subject_id else None,
            subject_name=m.subject.name if m.subject else None,
            teacher_id=str(m.teacher_id) if m.teacher_id else None,
            teacher_name=m.teacher.full_name if m.teacher else None,
        )

    def get_by_course(self, course_id: str) -> List[ClassPeriod]:
        rows = (
            self.db.query(ClassPeriodModel)
            .filter(ClassPeriodModel.course_id == course_id)
            .order_by(ClassPeriodModel.day_of_week, ClassPeriodModel.shift, ClassPeriodModel.period_order)
            .all()
        )
        return [self._to_entity(r) for r in rows]

    def create(
        self,
        *,
        course_id: str,
        day_of_week: int,
        shift: str,
        period_type: str,
        start_time: time,
        end_time: time,
        subject_id: Optional[str] = None,
        teacher_id: Optional[str] = None,
        is_fifth_module: bool = False,
    ) -> ClassPeriod:
        shift_enum = ShiftTypeEnum(shift)
        next_order = (
            self.db.query(func.coalesce(func.max(ClassPeriodModel.period_order), 0))
            .filter(
                ClassPeriodModel.course_id == course_id,
                ClassPeriodModel.day_of_week == day_of_week,
                ClassPeriodModel.shift == shift_enum,
            )
            .scalar()
        ) + 1

        model = ClassPeriodModel(
            course_id=course_id,
            day_of_week=day_of_week,
            shift=shift_enum,
            period_order=next_order,
            period_type=PeriodTypeEnum(period_type),
            subject_id=subject_id,
            teacher_id=teacher_id,
            start_time=start_time,
            end_time=end_time,
            is_fifth_module=is_fifth_module,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)

    def delete(self, id: str) -> bool:
        model = self.db.query(ClassPeriodModel).filter(ClassPeriodModel.id == id).first()
        if model is None:
            return False
        self.db.delete(model)
        self.db.commit()
        return True
