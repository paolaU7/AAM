import enum
from sqlalchemy import (
    Column, String, SmallInteger, Boolean, TIMESTAMP, Date, ForeignKey,
    UniqueConstraint, Table, Enum,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class EnrollmentTypeEnum(enum.Enum):
    regular = "regular"
    repeating = "repeating"  # recursante


# Per-student workshop membership (N:M student <-> workshop_group).
# A student ONLY belongs to the workshops they are individually enrolled in;
# this is NOT derived from course_workshop_groups (which is informational only).
student_workshop_groups = Table(
    "student_workshop_groups",
    Base.metadata,
    Column("student_id", String(36), ForeignKey("students.id", ondelete="CASCADE"), primary_key=True),
    Column("workshop_group_id", SmallInteger, ForeignKey("workshop_groups.id", ondelete="CASCADE"), primary_key=True),
    Column("joined_at", TIMESTAMP(timezone=True), nullable=False, server_default=func.now()),
)


class StudentModel(Base):
    __tablename__ = "students"

    id           = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    first_name   = Column(String(100), nullable=False)
    last_name    = Column(String(100), nullable=False)
    national_id  = Column(String(20), nullable=False, unique=True)   # DNI
    birth_date   = Column(Date, nullable=True)
    nfc_uid      = Column(String(64), unique=True, nullable=True)
    qr_code      = Column(String(64), unique=True, nullable=True)
    is_active    = Column(Boolean, nullable=False, default=True)
    created_at   = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    updated_at   = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    enrollments = relationship(
        "StudentCourseEnrollmentModel",
        back_populates="student",
        cascade="all, delete-orphan",
    )
    workshop_groups = relationship(
        "WorkshopGroupModel",
        secondary=student_workshop_groups,
        lazy="joined",
    )


class StudentCourseEnrollmentModel(Base):
    __tablename__ = "student_course_enrollments"

    id              = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    student_id      = Column(String(36), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    course_id       = Column(String(36), ForeignKey("courses.id"), nullable=False)
    enrollment_type = Column(Enum(EnrollmentTypeEnum, name="enrollment_type"), nullable=False,
                             default=EnrollmentTypeEnum.regular)
    start_date      = Column(Date, nullable=False, server_default=func.current_date())
    end_date        = Column(Date, nullable=True)

    student = relationship("StudentModel", back_populates="enrollments")
    course  = relationship("CourseModel", lazy="joined")

    __table_args__ = (
        UniqueConstraint("student_id", "course_id", "start_date"),
    )


class RepeatingSubjectModel(Base):
    __tablename__ = "repeating_subjects"

    id                   = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    student_id           = Column(String(36), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    subject_name         = Column(String(150), nullable=False)
    origin_academic_year = Column(SmallInteger, ForeignKey("academic_years.id"), nullable=False)
    origin_course_id     = Column(String(36), ForeignKey("courses.id"), nullable=True)
    created_at           = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
