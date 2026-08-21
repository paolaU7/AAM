import enum
from sqlalchemy import (
    Column, String, SmallInteger, Integer, TIMESTAMP, Date, Time, ForeignKey,
    CheckConstraint, UniqueConstraint, Enum,
)
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class ShiftTypeEnum(enum.Enum):
    morning = "morning"
    afternoon = "afternoon"
    evening = "evening"


class ActivityTypeEnum(enum.Enum):
    main_shift = "main_shift"   # turno principal (curso)
    workshop = "workshop"       # taller
    after_shift = "after_shift"  # contraturno


class TimeSlotModel(Base):
    """Recurring weekly time slot for a course OR a workshop group — exactly
    one of course_id / workshop_group_id is set, enforced by CHECK."""
    __tablename__ = "time_slots"

    id                     = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id              = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=True)
    workshop_group_id      = Column(String(36), ForeignKey("workshop_groups.id", ondelete="CASCADE"), nullable=True)
    shift                  = Column(Enum(ShiftTypeEnum, name="shift_type"), nullable=False)
    activity_type          = Column(Enum(ActivityTypeEnum, name="activity_type"), nullable=False,
                                     default=ActivityTypeEnum.main_shift)
    day_of_week            = Column(SmallInteger, nullable=False)  # ISO: 1 = Monday
    start_time             = Column(Time, nullable=False)
    end_time               = Column(Time, nullable=False)
    late_tolerance_minutes = Column(Integer, nullable=False, default=0)
    created_at             = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        CheckConstraint("day_of_week BETWEEN 1 AND 7", name="ck_time_slots_day_of_week"),
        CheckConstraint("end_time > start_time", name="ck_time_slots_time_order"),
        CheckConstraint(
            "(activity_type IN ('main_shift', 'after_shift') AND course_id IS NOT NULL AND workshop_group_id IS NULL)"
            " OR (activity_type = 'workshop' AND workshop_group_id IS NOT NULL AND course_id IS NULL)",
            name="ck_time_slots_course_xor_workshop",
        ),
    )


class ScheduleExceptionModel(Base):
    """Single-day exception to a course's normal schedule. Never affects
    attendance_rate."""
    __tablename__ = "schedule_exceptions"

    id             = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id      = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    exception_date = Column(Date, nullable=False)
    start_time     = Column(Time, nullable=True)
    end_time       = Column(Time, nullable=True)
    reason         = Column(String(255), nullable=True)
    created_by     = Column(String(36), ForeignKey("users.id"), nullable=False)
    created_at     = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("course_id", "exception_date", name="uq_schedule_exceptions_course_date"),
    )
