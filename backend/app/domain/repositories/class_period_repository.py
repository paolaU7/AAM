from abc import ABC, abstractmethod
from datetime import time
from typing import List, Optional
from app.domain.entities.class_period import ClassPeriod


class ClassPeriodRepository(ABC):

    @abstractmethod
    def get_by_course(self, course_id: str) -> List[ClassPeriod]:
        """Todos los períodos de este curso — curriculares (workshop_group_id
        NULL) y de contraturno de TODOS sus grupos de taller (course_id
        siempre apunta al curso, tengan o no grupo) — el frontend los separa
        por pestaña usando workshop_group_id."""
        ...

    @abstractmethod
    def create(
        self,
        *,
        course_id: str,
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
        """`course_id` siempre requerido; `workshop_group_id` opcional acota
        a un grupo de taller puntual. `period_order` se calcula solo:
        siguiente número dentro de (course_id, day_of_week, shift) si es
        curricular, o (workshop_group_id, day_of_week, shift) si es de taller."""
        ...

    @abstractmethod
    def delete(self, id: str) -> bool:
        """Returns False if the period doesn't exist."""
        ...
