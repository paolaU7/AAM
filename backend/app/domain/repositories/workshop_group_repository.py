from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.workshop_group import WorkshopGroup


class WorkshopGroupRepository(ABC):

    @abstractmethod
    def get_all(self) -> List[WorkshopGroup]: ...

    @abstractmethod
    def get_for_student(self, student_id: str) -> Optional[List[WorkshopGroup]]:
        """Workshops a student is individually enrolled in, or None if the
        student does not exist."""
        ...

    @abstractmethod
    def add_to_student(self, student_id: str, workshop_group_id: int) -> bool:
        """Returns False if the student or the workshop group does not exist."""
        ...

    @abstractmethod
    def remove_from_student(self, student_id: str, workshop_group_id: int) -> bool:
        """Returns False if the student does not exist."""
        ...
