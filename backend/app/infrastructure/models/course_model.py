from sqlalchemy import (
    Column, String, SmallInteger, Boolean, TIMESTAMP, Time, ForeignKey,
    UniqueConstraint, Table,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


# ── Course dimensions (independently editable/combinable) ────────────────────

class AcademicYearModel(Base):
    __tablename__ = "academic_years"

    id         = Column(SmallInteger, primary_key=True, autoincrement=True)
    name       = Column(String(50), nullable=False, unique=True)   # e.g. '4th Year'
    sort_order = Column(SmallInteger, nullable=False, unique=True)


class DivisionModel(Base):
    __tablename__ = "divisions"

    id   = Column(SmallInteger, primary_key=True, autoincrement=True)
    name = Column(String(20), nullable=False, unique=True)          # e.g. 'A', 'B'


class SpecialtyModel(Base):
    __tablename__ = "specialties"

    id   = Column(SmallInteger, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False, unique=True)


class ShiftModel(Base):
    __tablename__ = "shifts"

    id         = Column(SmallInteger, primary_key=True, autoincrement=True)
    name       = Column(String(50), nullable=False, unique=True)    # 'Morning'...
    start_time = Column(Time, nullable=False)
    end_time   = Column(Time, nullable=False)


class WorkshopGroupModel(Base):
    __tablename__ = "workshop_groups"

    id   = Column(SmallInteger, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False, unique=True)


# A course links to zero or more workshop groups (N:M).
course_workshop_groups = Table(
    "course_workshop_groups",
    Base.metadata,
    Column("course_id", String(36), ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True),
    Column("workshop_group_id", SmallInteger, ForeignKey("workshop_groups.id", ondelete="CASCADE"), primary_key=True),
)


# ── Course (combination of the four dimensions above) ────────────────────────

class CourseModel(Base):
    __tablename__ = "courses"

    id               = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    academic_year_id = Column(SmallInteger, ForeignKey("academic_years.id"), nullable=False)
    division_id      = Column(SmallInteger, ForeignKey("divisions.id"), nullable=False)
    specialty_id     = Column(SmallInteger, ForeignKey("specialties.id"), nullable=False)
    shift_id         = Column(SmallInteger, ForeignKey("shifts.id"), nullable=False)
    is_active        = Column(Boolean, nullable=False, default=True)
    created_at       = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    academic_year = relationship("AcademicYearModel", lazy="joined")
    division      = relationship("DivisionModel", lazy="joined")
    specialty     = relationship("SpecialtyModel", lazy="joined")
    shift         = relationship("ShiftModel", lazy="joined")
    workshop_groups = relationship(
        "WorkshopGroupModel",
        secondary=course_workshop_groups,
        lazy="joined",
    )

    __table_args__ = (
        UniqueConstraint("academic_year_id", "division_id", "specialty_id", "shift_id"),
    )
