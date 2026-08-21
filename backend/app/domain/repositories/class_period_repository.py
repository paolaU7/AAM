from abc import ABC, abstractmethod
from datetime import time
from typing import List, Optional
from app.domain.entities.class_period import ClassPeriod


class ClassPeriodRepository(ABC):

    @abstractmethod
    def get_by_course(self, course_id: str) -> List[ClassPeriod]: ...

    @abstractmethod
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
        """`period_order` se calcula solo: siguiente número dentro de
        (course_id, day_of_week, shift)."""
        ...

    @abstractmethod
    def delete(self, id: str) -> bool:
        """Returns False if the period doesn't exist."""
        ...
