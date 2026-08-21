from dataclasses import dataclass
from datetime import date as date_
from typing import Optional


@dataclass(frozen=True)
class CoursePreceptor:
    """Preceptor a cargo PERMANENTE de un curso, por turno, durante todo el
    año lectivo. Un curso puede tener un preceptor distinto por turno."""
    course_id: str
    shift: str
    preceptor_id: str
    preceptor_name: str


@dataclass(frozen=True)
class CoursePreceptorTempAssignment:
    """Reemplazo TEMPORAL (ej. licencia), con rango de fechas — máximo 1 mes,
    impuesto por CHECK en la base."""
    id: str
    course_id: str
    shift: str
    preceptor_id: str
    preceptor_name: str
    start_date: date_
    end_date: date_
    reason: Optional[str] = None
