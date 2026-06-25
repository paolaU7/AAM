from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.alumno import Alumno

class AlumnoRepository(ABC):

    @abstractmethod
    def get_alumnos(self) -> List[Alumno]: ...

    @abstractmethod
    def get_alumno_por_id(self, id: str) -> Optional[Alumno]: ...

    @abstractmethod
    def get_alumnos_por_curso(self, curso_id: str) -> List[Alumno]: ...

    @abstractmethod
    def crear_alumno(self, alumno: Alumno) -> Alumno: ...

    @abstractmethod
    def actualizar_alumno(self, id: str, alumno: Alumno) -> Optional[Alumno]: ...