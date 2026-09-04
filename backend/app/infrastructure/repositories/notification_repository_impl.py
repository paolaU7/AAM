from datetime import date
from itertools import groupby
from typing import List
from sqlalchemy.orm import Session
from app.domain.entities.notification import Notification
from app.domain.repositories.notification_repository import NotificationRepository
from app.infrastructure.models.preceptor_model import CoursePreceptorTempAssignmentModel
from app.infrastructure.models.schedule_model import ScheduleExceptionModel
from app.infrastructure.models.course_model import CourseModel
from app.infrastructure.models.student_model import StudentModel
from app.infrastructure.models.attendance_model import AttendanceRecordModel, AttendanceStatusEnum
from app.infrastructure.repositories.course_repository_impl import _grade_year_ordinal, _division_ordinal


def _curso_label(course: CourseModel) -> str:
    return f"{_grade_year_ordinal(course.grade_year)} {_division_ordinal(course.division)} ({course.academic_year})"


class NotificationRepositoryImpl(NotificationRepository):
    def __init__(self, db: Session):
        self.db = db

    def get_alerts(
        self,
        *,
        preceptor_temp_assignment_alert_days: int,
        schedule_exception_alert_days: int,
        consecutive_absences_alert_threshold: int,
    ) -> List[Notification]:
        alerts: List[Notification] = []
        alerts.extend(self._preceptor_temp_assignments_ending_soon(preceptor_temp_assignment_alert_days))
        alerts.extend(self._schedule_exceptions_upcoming(schedule_exception_alert_days))
        alerts.extend(self._consecutive_absences(consecutive_absences_alert_threshold))
        return alerts

    # ── 1) Reemplazos temporales de preceptor por vencer ────────────────────

    def _preceptor_temp_assignments_ending_soon(self, alert_days: int) -> List[Notification]:
        today = date.today()
        rows = (
            self.db.query(CoursePreceptorTempAssignmentModel, CourseModel)
            .join(CourseModel, CourseModel.id == CoursePreceptorTempAssignmentModel.course_id)
            .filter(CoursePreceptorTempAssignmentModel.end_date >= today)
            .all()
        )
        result = []
        for assignment, course in rows:
            days_left = (assignment.end_date - today).days
            if days_left > alert_days:
                continue
            if days_left == 0:
                cuando = "termina hoy"
            elif days_left == 1:
                cuando = "termina mañana"
            else:
                cuando = f"termina en {days_left} días"
            result.append(Notification(
                type="preceptor_temp_assignment",
                message=f"El reemplazo de {assignment.preceptor.full_name} en {_curso_label(course)} {cuando}",
            ))
        result.sort(key=lambda n: n.message)
        return result

    # ── 2) Excepciones de horario próximas ───────────────────────────────────

    def _schedule_exceptions_upcoming(self, alert_days: int) -> List[Notification]:
        today = date.today()
        rows = (
            self.db.query(ScheduleExceptionModel, CourseModel)
            .join(CourseModel, CourseModel.id == ScheduleExceptionModel.course_id)
            .filter(
                ScheduleExceptionModel.exception_date >= today,
            )
            .order_by(ScheduleExceptionModel.exception_date)
            .all()
        )
        result = []
        for exception, course in rows:
            days_left = (exception.exception_date - today).days
            if days_left > alert_days:
                continue
            fecha_str = exception.exception_date.strftime("%d/%m")
            motivo = f": {exception.reason}" if exception.reason else ""
            result.append(Notification(
                type="schedule_exception",
                message=f"{_curso_label(course)} tiene una excepción de horario el {fecha_str}{motivo}",
            ))
        return result

    # ── 3) Alumnos con faltas consecutivas ───────────────────────────────────

    def _consecutive_absences(self, threshold: int) -> List[Notification]:
        rows = (
            self.db.query(AttendanceRecordModel)
            .join(StudentModel, StudentModel.id == AttendanceRecordModel.student_id)
            .filter(StudentModel.is_active.is_(True))
            .order_by(AttendanceRecordModel.student_id, AttendanceRecordModel.entry_timestamp.desc())
            .all()
        )
        result = []
        for student_id, records in groupby(rows, key=lambda r: r.student_id):
            streak = 0
            student = None
            for record in records:
                student = record.student
                if record.status == AttendanceStatusEnum.absent:
                    streak += 1
                elif record.status == AttendanceStatusEnum.non_computable_absence:
                    # Diseñada para no afectar ninguna estadística — se
                    # saltea sin cortar ni sumar a la racha.
                    continue
                else:
                    # present / late / absent_with_presence: el alumno
                    # efectivamente apareció ese día, corta la racha.
                    break
            if streak >= threshold and student is not None:
                nombre = f"{student.last_name}, {student.first_name}"
                result.append(Notification(
                    type="consecutive_absences",
                    message=f"{nombre} lleva {streak} faltas consecutivas",
                ))
        result.sort(key=lambda n: n.message)
        return result
