from sqlalchemy import Column, String, SmallInteger, Boolean, TIMESTAMP, ForeignKey, UniqueConstraint, Table, Time
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base

class AcademicYearModel(Base):
    __tablename__ = "academic_years"

    id         = Column(SmallInteger, primary_key=True)
    name       = Column(String(50), nullable=False, unique=True)
    sort_order = Column(SmallInteger, nullable=False, unique=True)

    courses = relationship("CourseModel", back_populates="academic_year")


class DivisionModel(Base):
    __tablename__ = "divisions"

    id   = Column(SmallInteger, primary_key=True)
    name = Column(String(20), nullable=False, unique=True)

    courses = relationship("CourseModel", back_populates="division")


class SpecialtyModel(Base):
    __tablename__ = "specialties"

    id   = Column(SmallInteger, primary_key=True)
    name = Column(String(100), nullable=False, unique=True)

    courses = relationship("CourseModel", back_populates="specialty")


class ShiftModel(Base):
    __tablename__ = "shifts"

    id         = Column(SmallInteger, primary_key=True)
    name       = Column(String(50), nullable=False, unique=True)
    start_time = Column(Time, nullable=False)
    end_time   = Column(Time, nullable=False)

    courses = relationship("CourseModel", back_populates="shift")


class WorkshopGroupModel(Base):
    __tablename__ = "workshop_groups"

    id   = Column(SmallInteger, primary_key=True)
    name = Column(String(100), nullable=False, unique=True)

    courses = relationship(
        "CourseModel",
        secondary="course_workshop_groups",
        back_populates="workshop_groups"
    )


course_workshop_groups = Table(
    "course_workshop_groups",
    Base.metadata,
    Column("course_id", String(36), ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True),
    Column("workshop_group_id", SmallInteger, ForeignKey("workshop_groups.id", ondelete="CASCADE"), primary_key=True),
)


class CourseModel(Base):
    __tablename__ = "courses"

    id               = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    academic_year_id = Column(SmallInteger, ForeignKey("academic_years.id"), nullable=False)
    division_id      = Column(SmallInteger, ForeignKey("divisions.id"), nullable=False)
    specialty_id     = Column(SmallInteger, ForeignKey("specialties.id"), nullable=False)
    shift_id         = Column(SmallInteger, ForeignKey("shifts.id"), nullable=False)
    is_active        = Column(Boolean, nullable=False, default=True)
    created_at       = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    academic_year   = relationship("AcademicYearModel", back_populates="courses", lazy="joined")
    division        = relationship("DivisionModel", back_populates="courses", lazy="joined")
    specialty       = relationship("SpecialtyModel", back_populates="courses", lazy="joined")
    shift           = relationship("ShiftModel", back_populates="courses", lazy="joined")
    workshop_groups = relationship(
        "WorkshopGroupModel",
        secondary=course_workshop_groups,
        back_populates="courses",
        lazy="joined"
    )

    __table_args__ = (
        UniqueConstraint("academic_year_id", "division_id", "specialty_id", "shift_id"),
    )
