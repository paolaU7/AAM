from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.academic import Subject, SubjectApplicability, Teacher, SubjectTeacherAssignment


class SubjectRepository(ABC):
    @abstractmethod
    def get_all(self, grade_year: Optional[int] = None, specialty_id: Optional[str] = None) -> List[Subject]:
        """Sin filtros: catálogo completo (pantalla Materias). Con
        grade_year+specialty_id: solo las materias habilitadas (vía
        subject_applicability) para esa combinación puntual — lo que
        alimenta el desplegable al armar el horario de un curso."""
        ...

    @abstractmethod
    def get_by_id(self, id: str) -> Optional[Subject]: ...

    @abstractmethod
    def create(self, name: str, subject_type: str) -> Subject: ...


class SubjectApplicabilityRepository(ABC):
    @abstractmethod
    def get_by_subject(self, subject_id: str) -> List[SubjectApplicability]: ...

    @abstractmethod
    def add(self, subject_id: str, grade_year: int, specialty_id: str) -> SubjectApplicability: ...

    @abstractmethod
    def remove(self, id: str) -> bool: ...


class TeacherRepository(ABC):
    @abstractmethod
    def get_all(self) -> List[Teacher]: ...

    @abstractmethod
    def create(self, full_name: str, email: Optional[str] = None, phone: Optional[str] = None) -> Teacher: ...


class CourseSubjectTeacherRepository(ABC):
    @abstractmethod
    def get_by_course(self, course_id: str) -> List[SubjectTeacherAssignment]: ...

    @abstractmethod
    def get_by_teacher(self, teacher_id: str) -> List[SubjectTeacherAssignment]:
        """Todas las asignaciones de ESE profesor, en todos los cursos —
        para la ficha de Profes."""
        ...

    @abstractmethod
    def assign(self, course_id: str, subject_id: str, teacher_id: str) -> SubjectTeacherAssignment:
        """Upsert: si la materia ya estaba asignada a este curso, reemplaza
        el profesor (PK es course_id+subject_id)."""
        ...

    @abstractmethod
    def remove(self, course_id: str, subject_id: str) -> bool:
        """Returns False if the assignment didn't exist."""
        ...
