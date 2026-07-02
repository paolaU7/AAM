from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.course import Course

class CourseRepository(ABC):

    @abstractmethod
    def get_courses(self) -> List[Course]: ...

    @abstractmethod
    def get_course_by_id(self, id: str) -> Optional[Course]: ...

    @abstractmethod
    def get_courses_by_shift(self, shift_name: str) -> List[Course]: ...
