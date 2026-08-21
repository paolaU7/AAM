from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Subject:
    """Catálogo global de materias, reutilizable entre cursos y años."""
    id: str
    name: str


@dataclass(frozen=True)
class Teacher:
    """Profesor — dato de referencia para el horario. No tiene login."""
    id: str
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None


@dataclass(frozen=True)
class SubjectTeacherAssignment:
    """Qué materia dicta qué profesor, en UN curso puntual."""
    course_id: str
    subject_id: str
    subject_name: str
    teacher_id: str
    teacher_name: str
    teacher_email: Optional[str] = None
    teacher_phone: Optional[str] = None
