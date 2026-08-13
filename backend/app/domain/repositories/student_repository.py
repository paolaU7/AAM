from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.student import Alumno

class AlumnoRepository(ABC):

    @abstractmethod
    def get_alumnos(self) -> List[Alumno]: ...

    @abstractmethod
    def get_alumno_por_id(self, id: str) -> Optional[Alumno]: ...

    @abstractmethod
    def get_alumnos_por_curso(self, curso_id: str) -> List[Alumno]: ...

    @abstractmethod
    def actualizar_alumno(self, id: str, alumno: Alumno) -> Optional[Alumno]: ...

    @abstractmethod
    def existe_dni(self, dni: str) -> bool: ...

    @abstractmethod
    def crear_alumno_manual(
        self,
        first_name: str,
        last_name: str,
        national_id: str,
        course_id: str,
        workshop_group_id: Optional[str] = None,
    ) -> Alumno:
        """Creates the student directly enrolled in `course_id` (students.course_id
        is a direct FK — no enrollment-history table in the target schema).
        `workshop_group_id`, if given, must belong to that same course."""
        ...
