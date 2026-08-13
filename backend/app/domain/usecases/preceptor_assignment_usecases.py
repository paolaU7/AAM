import calendar
from datetime import date
from typing import List, Optional
from app.domain.entities.preceptor_assignment import CoursePreceptor, CoursePreceptorTempAssignment
from app.domain.repositories.preceptor_assignment_repository import (
    CoursePreceptorRepository, CoursePreceptorTempAssignmentRepository,
)


class PreceptorAssignmentError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


def add_one_calendar_month(d: date) -> date:
    """Replica `(d + INTERVAL '1 month')::date` de Postgres: mismo día del
    mes siguiente, recortado al último día válido si ese mes es más corto
    (ej. 31 ene -> 28/29 feb)."""
    year = d.year + (d.month // 12)
    month = d.month % 12 + 1
    last_day = calendar.monthrange(year, month)[1]
    day = min(d.day, last_day)
    return date(year, month, day)


class GetCoursePreceptors:
    def __init__(self, repo: CoursePreceptorRepository):
        self.repo = repo

    def execute(self, course_id: str) -> List[CoursePreceptor]:
        return self.repo.get_by_course(course_id)


class AssignCoursePreceptor:
    def __init__(self, repo: CoursePreceptorRepository):
        self.repo = repo

    def execute(self, course_id: str, shift: str, preceptor_id: str) -> CoursePreceptor:
        if not preceptor_id:
            raise PreceptorAssignmentError("El preceptor es obligatorio.", 400)
        return self.repo.assign(course_id, shift, preceptor_id)


class RemoveCoursePreceptor:
    def __init__(self, repo: CoursePreceptorRepository):
        self.repo = repo

    def execute(self, course_id: str, shift: str) -> bool:
        return self.repo.remove(course_id, shift)


class GetCoursePreceptorTempAssignments:
    def __init__(self, repo: CoursePreceptorTempAssignmentRepository):
        self.repo = repo

    def execute(self, course_id: str) -> List[CoursePreceptorTempAssignment]:
        return self.repo.get_by_course(course_id)


class CreateCoursePreceptorTempAssignment:
    def __init__(self, repo: CoursePreceptorTempAssignmentRepository):
        self.repo = repo

    def execute(
        self, *, course_id: str, shift: str, preceptor_id: str,
        start_date: date, end_date: date, reason: Optional[str], created_by: str,
    ) -> CoursePreceptorTempAssignment:
        if not preceptor_id:
            raise PreceptorAssignmentError("El preceptor es obligatorio.", 400)
        if not created_by:
            raise PreceptorAssignmentError("Falta indicar quién asigna el reemplazo.", 400)
        if end_date < start_date:
            raise PreceptorAssignmentError("La fecha de fin no puede ser anterior a la de inicio.", 400)
        limite = add_one_calendar_month(start_date)
        if end_date > limite:
            raise PreceptorAssignmentError(
                f"El reemplazo temporal no puede superar 1 mes (hasta {limite.isoformat()} como máximo).", 400,
            )

        return self.repo.create(
            course_id=course_id, shift=shift, preceptor_id=preceptor_id,
            start_date=start_date, end_date=end_date, reason=reason, created_by=created_by,
        )


class DeleteCoursePreceptorTempAssignment:
    def __init__(self, repo: CoursePreceptorTempAssignmentRepository):
        self.repo = repo

    def execute(self, id: str) -> bool:
        return self.repo.delete(id)
