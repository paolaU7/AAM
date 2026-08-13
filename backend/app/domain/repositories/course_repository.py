from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.course import Course


class CourseRepository(ABC):

    @abstractmethod
    def get_courses(self) -> List[Course]: ...

    @abstractmethod
    def get_course_by_id(self, id: str) -> Optional[Course]: ...

    @abstractmethod
    def resolve_course(self, academic_year: int, grade_year: int, division: int) -> Optional[Course]:
        """The course identified by the (academic_year, grade_year, division)
        UNIQUE triple, or None if it doesn't exist. Used by the Excel import
        flow, which only knows the 3 dimensions from the file header."""
        ...

    @abstractmethod
    def create_course(
        self, academic_year: int, grade_year: int, division: int, specialty: Optional[str] = None,
    ) -> Course: ...
