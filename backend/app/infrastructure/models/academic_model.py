import enum
from sqlalchemy import (
    Column, String, Text, TIMESTAMP, Time, SmallInteger, Boolean, ForeignKey,
    Enum, CheckConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base
from app.infrastructure.models.schedule_model import ShiftTypeEnum


class SubjectTypeEnum(enum.Enum):
    # nombre del miembro == valor Postgres acá, no hace falta values_callable.
    curricular = "curricular"
    workshop = "workshop"


class SubjectModel(Base):
    __tablename__ = "subjects"

    id           = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    name         = Column(Text, nullable=False, unique=True)
    subject_type = Column(Enum(SubjectTypeEnum, name="subject_type"), nullable=False)
    created_at   = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())


class SubjectApplicabilityModel(Base):
    """En qué año de cursada (+especialidad) se puede dictar una materia —
    una materia puede tener varias filas (una por año/especialidad habilitado)."""
    __tablename__ = "subject_applicability"

    id           = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    subject_id   = Column(String(36), ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    grade_year   = Column(SmallInteger, nullable=False)
    specialty_id = Column(String(36), ForeignKey("specialties.id"), nullable=False)

    subject = relationship("SubjectModel", lazy="joined")
    specialty = relationship("SpecialtyModel", lazy="joined")

    __table_args__ = (
        CheckConstraint("grade_year BETWEEN 1 AND 7", name="ck_subject_applicability_grade_year"),
    )


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

    course = relationship("CourseModel", lazy="joined")
    subject = relationship("SubjectModel", lazy="joined")
    teacher = relationship("TeacherModel", lazy="joined")


class PeriodTypeEnum(enum.Enum):
    # el valor Postgres es 'class'; el nombre del miembro Python no puede
    # ser `class` (palabra reservada).
    lesson = "class"
    recess = "recess"
    lunch = "lunch"


class ClassPeriodModel(Base):
    """Horario académico DETALLADO día por día — distinto de `time_slots`
    (que solo abre/cierra el turno de asistencia). `course_id` SIEMPRE está
    seteado (todo período pertenece a un curso); `workshop_group_id` es
    opcional y, cuando está seteado, acota el período a UN grupo de taller
    puntual dentro de ese mismo curso (contraturno). La unicidad real
    (curricular vs. taller) vive en dos índices únicos parciales en la DB
    (`idx_class_periods_curricular_unique` / `..._workshop_unique`, no
    modelados acá como UniqueConstraint porque SQLAlchemy no declara
    índices parciales vía table_args de forma directa), y la consistencia
    grupo↔curso la valida un trigger (`enforce_class_period_workshop_group_course`)."""
    __tablename__ = "class_periods"

    id                 = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id          = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    workshop_group_id  = Column(String(36), ForeignKey("workshop_groups.id", ondelete="CASCADE"), nullable=True)
    day_of_week        = Column(SmallInteger, nullable=False)  # ISO: 1 = lunes
    shift               = Column(Enum(ShiftTypeEnum, name="shift_type"), nullable=False)
    period_order        = Column(SmallInteger, nullable=False)
    # values_callable: sin esto, SQLAlchemy manda el *nombre* del miembro
    # Python ("lesson") en vez de su valor ("class") — y el enum de Postgres
    # solo conoce 'class'/'recess'/'lunch'.
    period_type         = Column(
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
    )
