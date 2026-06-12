from __future__ import annotations
from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.alumno import Alumno


class AlumnoRepository(ABC):
    @abstractmethod
    async def list_all(self) -> List[Alumno]:
        raise NotImplementedError()

    @abstractmethod
    async def get_by_dni(self, dni: str) -> Optional[Alumno]:
        raise NotImplementedError()

    @abstractmethod
    async def add(self, alumno: Alumno) -> Alumno:
        raise NotImplementedError()
