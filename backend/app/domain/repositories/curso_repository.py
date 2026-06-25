from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.curso import Curso

class CursoRepository(ABC):

    @abstractmethod
    def get_cursos(self) -> List[Curso]: ...

    @abstractmethod
    def get_curso_por_id(self, id: str) -> Optional[Curso]: ...

    @abstractmethod
    def get_cursos_por_turno(self, turno: str) -> List[Curso]: ...