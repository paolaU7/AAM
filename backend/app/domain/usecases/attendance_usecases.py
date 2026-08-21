from datetime import date, datetime
from typing import List, Optional
from app.domain.entities.attendance_record import RegistroAsistencia, ResumenAsistencia
from app.domain.repositories.attendance_repository import AsistenciaRepository


class RegistrarAsistenciaError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class GetRegistrosPorCursoYFecha:
    def __init__(self, repo: AsistenciaRepository):
        self.repo = repo

    def execute(self, course_id: str, fecha: date) -> List[RegistroAsistencia]:
        return self.repo.get_by_course_and_date(course_id, fecha)


class GetResumenDiario:
    def __init__(self, repo: AsistenciaRepository):
        self.repo = repo

    def execute(self, fecha: date) -> ResumenAsistencia:
        return self.repo.get_daily_summary(fecha)


class GetResumenPorTurno:
    def __init__(self, repo: AsistenciaRepository):
        self.repo = repo

    def execute(self, shift: str, fecha: date) -> ResumenAsistencia:
        return self.repo.get_summary_by_shift(shift, fecha)


class RegistrarIngresoManual:
    def __init__(self, repo: AsistenciaRepository):
        self.repo = repo

    def execute(self, *, student_id: str, course_id: str, entry_timestamp: datetime, status: str) -> RegistroAsistencia:
        if not student_id or not course_id:
            raise RegistrarAsistenciaError("Alumno y curso son obligatorios.", 400)
        return self.repo.register_manual_check_in(
            student_id=student_id, course_id=course_id,
            entry_timestamp=entry_timestamp, status=status,
        )


class RegistrarRetiroAnticipado:
    def __init__(self, repo: AsistenciaRepository):
        self.repo = repo

    def execute(self, *, record_id: str, departure_time: datetime, reason: str, registered_by: str) -> RegistroAsistencia:
        reason = (reason or "").strip()
        if not reason:
            raise RegistrarAsistenciaError("El motivo del retiro es obligatorio.", 400)
        if not registered_by:
            raise RegistrarAsistenciaError("Falta indicar quién registra el retiro.", 400)
        registro = self.repo.register_early_departure(
            record_id=record_id, departure_time=departure_time,
            reason=reason, registered_by=registered_by,
        )
        if registro is None:
            raise RegistrarAsistenciaError("El registro de asistencia no existe.", 404)
        return registro


class MarcarNoComputable:
    def __init__(self, repo: AsistenciaRepository):
        self.repo = repo

    def execute(self, record_id: str) -> RegistroAsistencia:
        registro = self.repo.mark_non_computable(record_id)
        if registro is None:
            raise RegistrarAsistenciaError("El registro de asistencia no existe.", 404)
        return registro
