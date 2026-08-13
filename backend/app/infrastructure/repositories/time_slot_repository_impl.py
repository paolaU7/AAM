from datetime import time
from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.time_slot import TimeSlot
from app.domain.repositories.time_slot_repository import TimeSlotRepository
from app.infrastructure.models.schedule_model import TimeSlotModel, ShiftTypeEnum, ActivityTypeEnum


class TimeSlotRepositoryImpl(TimeSlotRepository):

    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(model: TimeSlotModel) -> TimeSlot:
        return TimeSlot(
            id=str(model.id),
            shift=model.shift.value,
            activity_type=model.activity_type.value,
            day_of_week=model.day_of_week,
            start_time=model.start_time,
            end_time=model.end_time,
            late_tolerance_minutes=model.late_tolerance_minutes,
            course_id=str(model.course_id) if model.course_id else None,
            workshop_group_id=str(model.workshop_group_id) if model.workshop_group_id else None,
        )

    def get_by_course(self, course_id: str) -> List[TimeSlot]:
        rows = self.db.query(TimeSlotModel).filter(TimeSlotModel.course_id == course_id).all()
        return [self._to_entity(r) for r in rows]

    def get_by_workshop_group(self, workshop_group_id: str) -> List[TimeSlot]:
        rows = (
            self.db.query(TimeSlotModel)
            .filter(TimeSlotModel.workshop_group_id == workshop_group_id)
            .all()
        )
        return [self._to_entity(r) for r in rows]

    def create(
        self,
        *,
        course_id: Optional[str],
        workshop_group_id: Optional[str],
        shift: str,
        activity_type: str,
        day_of_week: int,
        start_time: time,
        end_time: time,
        late_tolerance_minutes: int = 0,
    ) -> TimeSlot:
        model = TimeSlotModel(
            course_id=course_id,
            workshop_group_id=workshop_group_id,
            shift=ShiftTypeEnum(shift),
            activity_type=ActivityTypeEnum(activity_type),
            day_of_week=day_of_week,
            start_time=start_time,
            end_time=end_time,
            late_tolerance_minutes=late_tolerance_minutes,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)

    def delete(self, id: str) -> bool:
        model = self.db.query(TimeSlotModel).filter(TimeSlotModel.id == id).first()
        if model is None:
            return False
        self.db.delete(model)
        self.db.commit()
        return True
