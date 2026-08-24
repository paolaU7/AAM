from abc import ABC, abstractmethod
from datetime import time
from typing import List, Optional
from app.domain.entities.class_period import ClassPeriod


class ClassPeriodRepository(ABC):

    @abstractmethod
    def get_by_course(self, course_id: str) -> List[ClassPeriod]:
        """Incluye tanto los períodos curriculares del curso (course_id-scoped)
        como los períodos de contraturno de TODOS sus grupos de taller
        (workshop_group_id-scoped) — el frontend los separa por pestaña."""
        ...

    @abstractmethod
    def create(
        self,
        *,
        course_id: Optional[str] = None,
        workshop_group_id: Optional[str] = None,
        day_of_week: int,
        shift: str,
        period_type: str,
        start_time: time,
        end_time: time,
        subject_id: Optional[str] = None,
        teacher_id: Optional[str] = None,
        is_fifth_module: bool = False,
    ) -> ClassPeriod:
        """Exactamente uno de course_id / workshop_group_id. `period_order`
        se calcula solo: siguiente número dentro de (scope, day_of_week, shift)."""
        ...

    @abstractmethod
    def delete(self, id: str) -> bool:
        """Returns False if the period doesn't exist."""
        ...
