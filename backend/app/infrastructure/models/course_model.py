from sqlalchemy import Column, String, SmallInteger, Text, TIMESTAMP, ForeignKey, CheckConstraint, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class CourseModel(Base):
    """A course is the combination of three independent numeric dimensions:
    academic_year (calendar year), grade_year (1..7) and division.
    `specialty_id` is SIEMPRE obligatorio — para 1ro/2do/3ro apunta a la
    especialidad "Ciclo Básico" (asignada automáticamente por la UI, nunca
    a mano); un trigger en la DB (`enforce_basic_cycle_specialty`) rechaza
    cualquier combinación inválida como red de seguridad."""
    __tablename__ = "courses"

    id            = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    academic_year = Column(SmallInteger, nullable=False)
    grade_year    = Column(SmallInteger, nullable=False)
    division      = Column(SmallInteger, nullable=False)
    specialty_id  = Column(String(36), ForeignKey("specialties.id"), nullable=False)
    created_at    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    specialty = relationship("SpecialtyModel", lazy="joined")

    __table_args__ = (
        CheckConstraint("grade_year BETWEEN 1 AND 7", name="ck_courses_grade_year"),
        CheckConstraint("division > 0", name="ck_courses_division"),
        UniqueConstraint("academic_year", "grade_year", "division", name="uq_courses_dimensions"),
    )


class WorkshopGroupModel(Base):
    """Subdivisión interna de UN curso puntual (Grupo A, B, C...) — no se
    comparte entre cursos distintos, aunque den las mismas materias de
    taller en horarios distintos."""
    __tablename__ = "workshop_groups"

    id            = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id     = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    group_label   = Column(Text, nullable=False)
    created_at    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("course_id", "group_label", name="uq_workshop_groups_course_label"),
    )
