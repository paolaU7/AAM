import enum
from sqlalchemy import (
    Column, String, Text, TIMESTAMP, Time, SmallInteger, Boolean, ForeignKey,
    Enum, UniqueConstraint, CheckConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base
from app.infrastructure.models.schedule_model import ShiftTypeEnum


class SubjectModel(Base):
    __tablename__ = "subjects"

    id         = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    name       = Column(Text, nullable=False, unique=True)
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())


class TeacherModel(Base):
    """No tienen login: son datos de referencia para mostrar en el horario."""
    __tablename__ = "teachers"

    id         = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    full_name  = Column(Text, nullable=False)
    email      = Column(Text, nullable=True)
    phone      = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())


class CourseSubjectTeacherModel(Base):
    """Qué materia dicta qué profesor, EN un curso puntual."""
    __tablename__ = "course_subject_teachers"

    course_id  = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True)
    subject_id = Column(String(36), ForeignKey("subjects.id"), primary_key=True)
    teacher_id = Column(String(36), ForeignKey("teachers.id"), nullable=False)

    subject = relationship("SubjectModel", lazy="joined")
    teacher = relationship("TeacherModel", lazy="joined")


class PeriodTypeEnum(enum.Enum):
    # el valor Postgres es 'class'; el nombre del miembro Python no puede
    # ser `class` (palabra reservada).
    lesson = "class"
    recess = "recess"
    lunch = "lunch"


class ClassPeriodModel(Base):
    """Horario académico DETALLADO día por día de un curso — distinto de
    `time_slots` (que solo abre/cierra el turno de asistencia)."""
    __tablename__ = "class_periods"

    id              = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id       = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    day_of_week     = Column(SmallInteger, nullable=False)  # ISO: 1 = lunes
    shift           = Column(Enum(ShiftTypeEnum, name="shift_type"), nullable=False)
    period_order    = Column(SmallInteger, nullable=False)
    # values_callable: sin esto, SQLAlchemy manda el *nombre* del miembro
    # Python ("lesson") en vez de su valor ("class") — y el enum de Postgres
    # solo conoce 'class'/'recess'/'lunch'.
    period_type     = Column(
        Enum(PeriodTypeEnum, name="period_type", values_callable=lambda e: [m.value for m in e]),
        nullable=False,
    )
    subject_id      = Column(String(36), ForeignKey("subjects.id"), nullable=True)
    teacher_id      = Column(String(36), ForeignKey("teachers.id"), nullable=True)
    start_time      = Column(Time, nullable=False)
    end_time        = Column(Time, nullable=False)
    is_fifth_module = Column(Boolean, nullable=False, default=False)

    subject = relationship("SubjectModel", lazy="joined")
    teacher = relationship("TeacherModel", lazy="joined")

    __table_args__ = (
        CheckConstraint("day_of_week BETWEEN 1 AND 7", name="ck_class_periods_day_of_week"),
        CheckConstraint("end_time > start_time", name="ck_class_periods_time_order"),
        UniqueConstraint("course_id", "day_of_week", "shift", "period_order", name="uq_class_periods_order"),
    )
