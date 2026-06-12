from __future__ import annotations
from abc import ABC, abstractmethod
from typing import Optional, List
from app.domain.entities.asistencia import Asistencia


class AsistenciaRepository(ABC):
    @abstractmethod
    async def add(self, asistencia: Asistencia) -> Asistencia:
        raise NotImplementedError()

    @abstractmethod
    async def get_by_ulid(self, ulid: str) -> Optional[Asistencia]:
        raise NotImplementedError()

    @abstractmethod
    async def list_all(self) -> List[Asistencia]:
        raise NotImplementedError()
