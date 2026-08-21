from abc import ABC, abstractmethod
from datetime import time
from typing import List, Optional
from app.domain.entities.time_slot import TimeSlot


class TimeSlotRepository(ABC):

    @abstractmethod
    def get_by_course(self, course_id: str) -> List[TimeSlot]: ...

    @abstractmethod
    def get_by_workshop_group(self, workshop_group_id: str) -> List[TimeSlot]: ...

    @abstractmethod
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
    ) -> TimeSlot: ...

    @abstractmethod
    def delete(self, id: str) -> bool:
        """Returns False if the time slot doesn't exist."""
        ...
