from abc import ABC, abstractmethod
from datetime import date, datetime
from typing import List, Optional
from app.domain.entities.attendance_record import RegistroAsistencia, ResumenAsistencia


class AsistenciaRepository(ABC):

    @abstractmethod
    def get_by_course_and_date(self, course_id: str, fecha: date) -> List[RegistroAsistencia]: ...

    @abstractmethod
    def get_daily_summary(self, fecha: date) -> ResumenAsistencia: ...

    @abstractmethod
    def get_summary_by_shift(self, shift: str, fecha: date) -> ResumenAsistencia:
        """Solo cuenta registros ligados a un time_slot con ese shift — los
        registros manuales sin time_slot_id quedan fuera de este corte."""
        ...

    @abstractmethod
    def register_manual_check_in(
        self, student_id: str, course_id: str, entry_timestamp: datetime, status: str,
    ) -> RegistroAsistencia:
        """El estado (presente/tarde/etc.) lo elige el preceptor al cargar —
        no hay time_slot asociado para inferirlo automáticamente."""
        ...

    @abstractmethod
    def register_early_departure(
        self, record_id: str, departure_time: datetime, reason: str, registered_by: str,
    ) -> Optional[RegistroAsistencia]: ...

    @abstractmethod
    def mark_non_computable(self, record_id: str) -> Optional[RegistroAsistencia]:
        """No hay dónde persistir un motivo de texto en el schema real
        (no existe tabla non_computable_absences) — solo cambia el status."""
        ...
