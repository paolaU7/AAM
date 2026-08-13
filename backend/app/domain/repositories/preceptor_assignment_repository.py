from abc import ABC, abstractmethod
from datetime import date
from typing import List, Optional
from app.domain.entities.preceptor_assignment import CoursePreceptor, CoursePreceptorTempAssignment


class CoursePreceptorRepository(ABC):

    @abstractmethod
    def get_by_course(self, course_id: str) -> List[CoursePreceptor]: ...

    @abstractmethod
    def assign(self, course_id: str, shift: str, preceptor_id: str) -> CoursePreceptor:
        """Upsert: PK es (course_id, shift), reemplaza si ya había uno."""
        ...

    @abstractmethod
    def remove(self, course_id: str, shift: str) -> bool: ...


class CoursePreceptorTempAssignmentRepository(ABC):

    @abstractmethod
    def get_by_course(self, course_id: str) -> List[CoursePreceptorTempAssignment]: ...

    @abstractmethod
    def create(
        self, *, course_id: str, shift: str, preceptor_id: str,
        start_date: date, end_date: date, reason: Optional[str], created_by: str,
    ) -> CoursePreceptorTempAssignment:
        """`created_by` es NOT NULL en la DB (quién asignó el reemplazo) —
        no hay sesión/login todavía, así que lo elige la UI explícitamente."""
        ...

    @abstractmethod
    def delete(self, id: str) -> bool: ...
