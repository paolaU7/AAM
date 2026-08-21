from abc import ABC, abstractmethod
from typing import List
from app.domain.entities.workshop_group import WorkshopGroup


class WorkshopGroupRepository(ABC):

    @abstractmethod
    def get_all(self) -> List[WorkshopGroup]: ...

    @abstractmethod
    def get_by_course(self, course_id: str) -> List[WorkshopGroup]:
        """Grupos definidos para UN curso puntual — no se comparten entre
        cursos distintos."""
        ...
