from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Subject:
    """Catálogo global de materias, reutilizable entre cursos y años.
    `subject_type` ('curricular' | 'workshop') es fijo desde el alta — si la
    misma materia se dicta en ambos contextos, son dos filas distintas."""
    id: str
    name: str
    subject_type: str


@dataclass(frozen=True)
class SubjectApplicability:
    """En qué año de cursada (+especialidad, si es 4to o más) se puede
    dictar una materia. Una materia puede tener varias filas de estas a la
    vez (uno por cada año/especialidad habilitado)."""
    id: str
    subject_id: str
    grade_year: int
    specialty_id: str
    specialty_name: str


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
    subject_type: str
    teacher_id: str
    teacher_name: str
    teacher_email: Optional[str] = None
    teacher_phone: Optional[str] = None
    course_name: Optional[str] = None
