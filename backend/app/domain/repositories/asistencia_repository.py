from abc import ABC, abstractmethod
from typing import List
from datetime import date
from app.domain.entities.registro_asistencia import RegistroAsistencia

class AsistenciaRepository(ABC):

    @abstractmethod
    def get_asistencia_diaria(self, curso_id: str, fecha: date) -> List[RegistroAsistencia]: ...

    @abstractmethod
    def crear_registro(self, registro: RegistroAsistencia) -> RegistroAsistencia: ...