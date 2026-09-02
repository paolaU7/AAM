from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.specialty import Specialty, SchoolSettings


class SpecialtyRepository(ABC):

    @abstractmethod
    def get_all(self) -> List[Specialty]: ...

    @abstractmethod
    def get_by_id(self, id: str) -> Optional[Specialty]: ...


class SchoolSettingsRepository(ABC):

    @abstractmethod
    def get(self) -> SchoolSettings:
        """Siempre hay exactamente una fila (sembrada por el schema)."""
        ...
