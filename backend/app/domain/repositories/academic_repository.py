from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.academic import Subject, Teacher, SubjectTeacherAssignment


class SubjectRepository(ABC):
    @abstractmethod
    def get_all(self) -> List[Subject]: ...

    @abstractmethod
    def create(self, name: str) -> Subject: ...


class TeacherRepository(ABC):
    @abstractmethod
    def get_all(self) -> List[Teacher]: ...

    @abstractmethod
    def create(self, full_name: str, email: Optional[str] = None, phone: Optional[str] = None) -> Teacher: ...


class CourseSubjectTeacherRepository(ABC):
    @abstractmethod
    def get_by_course(self, course_id: str) -> List[SubjectTeacherAssignment]: ...

    @abstractmethod
    def assign(self, course_id: str, subject_id: str, teacher_id: str) -> SubjectTeacherAssignment:
        """Upsert: si la materia ya estaba asignada a este curso, reemplaza
        el profesor (PK es course_id+subject_id)."""
        ...

    @abstractmethod
    def remove(self, course_id: str, subject_id: str) -> bool:
        """Returns False if the assignment didn't exist."""
        ...
