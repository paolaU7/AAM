import enum
from sqlalchemy import (
    Column, String, CHAR, TIMESTAMP, ForeignKey, Enum,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class AttendanceStatusEnum(enum.Enum):
    present               = "present"                 # presente
    late                  = "late"                    # tarde / tardanza
    absent                = "absent"                  # ausente
    absent_with_presence  = "absent_with_presence"     # ausente_con_permanencia
    non_computable_absence = "non_computable_absence"  # falta_no_computable — does not affect RITE


class AttendanceSourceEnum(enum.Enum):
    nfc    = "nfc"
    qr     = "qr"
    manual = "manual"


class AttendanceRecordModel(Base):
    __tablename__ = "attendance_records"

    # ULID generated on the ESP32 device (26 chars, lexicographically sortable).
    id                = Column(CHAR(26), primary_key=True)
    student_id        = Column(String(36), ForeignKey("students.id"), nullable=False)
    course_id         = Column(String(36), ForeignKey("courses.id"), nullable=False)
    workshop_group_id = Column(String(36), ForeignKey("workshop_groups.id"), nullable=True)
    time_slot_id      = Column(String(36), ForeignKey("time_slots.id"), nullable=True)
    device_id         = Column(String(36), ForeignKey("devices.id"), nullable=True)   # null when source = manual
    registered_by     = Column(String(36), ForeignKey("users.id"), nullable=True)     # preceptor, when source = manual
    source            = Column(Enum(AttendanceSourceEnum, name="attendance_source"), nullable=False)
    status            = Column(Enum(AttendanceStatusEnum, name="attendance_status"), nullable=False)
    entry_timestamp   = Column(TIMESTAMP(timezone=True), nullable=False)
    synced_at         = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    created_at        = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    student = relationship("StudentModel", lazy="joined")
    course  = relationship("CourseModel", lazy="joined")


class EarlyDepartureModel(Base):
    __tablename__ = "early_departures"

    id                    = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    attendance_record_id  = Column(CHAR(26), ForeignKey("attendance_records.id", ondelete="CASCADE"), nullable=False)
    departure_time        = Column(TIMESTAMP(timezone=True), nullable=False)
    reason                = Column(String(255), nullable=False)
    registered_by         = Column(String(36), ForeignKey("users.id"), nullable=False)
    created_at            = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
