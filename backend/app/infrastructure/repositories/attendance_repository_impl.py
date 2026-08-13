from datetime import date, datetime
from typing import List, Optional
from ulid import ULID
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.domain.entities.attendance_record import RegistroAsistencia, ResumenAsistencia
from app.domain.repositories.attendance_repository import AsistenciaRepository
from app.infrastructure.models.attendance_model import (
    AttendanceRecordModel, EarlyDepartureModel, AttendanceStatusEnum, AttendanceSourceEnum,
)
from app.infrastructure.models.schedule_model import TimeSlotModel, ShiftTypeEnum

_ABSENT_LIKE = (AttendanceStatusEnum.absent, AttendanceStatusEnum.absent_with_presence)


class AsistenciaRepositoryImpl(AsistenciaRepository):

    def __init__(self, db: Session):
        self.db = db

    def _to_entity(self, model: AttendanceRecordModel, departure: Optional[EarlyDepartureModel]) -> RegistroAsistencia:
        student = model.student
        return RegistroAsistencia(
            id=model.id,
            student_id=str(model.student_id),
            student_name=f"{student.last_name}, {student.first_name}" if student else "",
            course_id=str(model.course_id),
            entry_timestamp=model.entry_timestamp,
            source=model.source.value,
            status=model.status.value,
            departure_time=departure.departure_time if departure else None,
            departure_reason=departure.reason if departure else None,
        )

    def _departures_by_record(self, record_ids: List[str]) -> dict:
        if not record_ids:
            return {}
        rows = (
            self.db.query(EarlyDepartureModel)
            .filter(EarlyDepartureModel.attendance_record_id.in_(record_ids))
            .all()
        )
        return {d.attendance_record_id: d for d in rows}

    def get_by_course_and_date(self, course_id: str, fecha: date) -> List[RegistroAsistencia]:
        rows = (
            self.db.query(AttendanceRecordModel)
            .filter(
                AttendanceRecordModel.course_id == course_id,
                func.date(AttendanceRecordModel.entry_timestamp) == fecha,
            )
            .order_by(AttendanceRecordModel.entry_timestamp)
            .all()
        )
        departures = self._departures_by_record([r.id for r in rows])
        return [self._to_entity(r, departures.get(r.id)) for r in rows]

    def _summarize(self, rows: List[AttendanceRecordModel], fecha: date) -> ResumenAsistencia:
        present = sum(1 for r in rows if r.status == AttendanceStatusEnum.present)
        absent = sum(1 for r in rows if r.status in _ABSENT_LIKE)
        late = sum(1 for r in rows if r.status == AttendanceStatusEnum.late)
        non_computable = sum(1 for r in rows if r.status == AttendanceStatusEnum.non_computable_absence)
        departures = self._departures_by_record([r.id for r in rows])
        return ResumenAsistencia(
            date=fecha, present=present, absent=absent, late=late,
            non_computable_absence=non_computable, early_departures=len(departures),
            total=len(rows),
        )

    def get_daily_summary(self, fecha: date) -> ResumenAsistencia:
        rows = (
            self.db.query(AttendanceRecordModel)
            .filter(func.date(AttendanceRecordModel.entry_timestamp) == fecha)
            .all()
        )
        return self._summarize(rows, fecha)

    def get_summary_by_shift(self, shift: str, fecha: date) -> ResumenAsistencia:
        rows = (
            self.db.query(AttendanceRecordModel)
            .join(TimeSlotModel, TimeSlotModel.id == AttendanceRecordModel.time_slot_id)
            .filter(
                TimeSlotModel.shift == ShiftTypeEnum(shift),
                func.date(AttendanceRecordModel.entry_timestamp) == fecha,
            )
            .all()
        )
        return self._summarize(rows, fecha)

    def register_manual_check_in(
        self, student_id: str, course_id: str, entry_timestamp: datetime, status: str,
    ) -> RegistroAsistencia:
        model = AttendanceRecordModel(
            id=str(ULID()),
            student_id=student_id,
            course_id=course_id,
            source=AttendanceSourceEnum.manual,
            status=AttendanceStatusEnum(status),
            entry_timestamp=entry_timestamp,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model, None)

    def register_early_departure(
        self, record_id: str, departure_time: datetime, reason: str, registered_by: str,
    ) -> Optional[RegistroAsistencia]:
        record = self.db.query(AttendanceRecordModel).filter(AttendanceRecordModel.id == record_id).first()
        if record is None:
            return None
        departure = EarlyDepartureModel(
            attendance_record_id=record_id,
            departure_time=departure_time,
            reason=reason,
            registered_by=registered_by,
        )
        self.db.add(departure)
        self.db.commit()
        self.db.refresh(record)
        return self._to_entity(record, departure)

    def mark_non_computable(self, record_id: str) -> Optional[RegistroAsistencia]:
        record = self.db.query(AttendanceRecordModel).filter(AttendanceRecordModel.id == record_id).first()
        if record is None:
            return None
        record.status = AttendanceStatusEnum.non_computable_absence
        self.db.commit()
        self.db.refresh(record)
        departure = (
            self.db.query(EarlyDepartureModel)
            .filter(EarlyDepartureModel.attendance_record_id == record_id)
            .first()
        )
        return self._to_entity(record, departure)
