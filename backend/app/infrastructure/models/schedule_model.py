import enum
from sqlalchemy import (
    Column, String, SmallInteger, TIMESTAMP, Date, Time, ForeignKey,
    CheckConstraint, Enum,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class ActivityTypeEnum(enum.Enum):
    regular        = "regular"          # turno principal
    workshop       = "workshop"         # taller
    extended_shift = "extended_shift"   # contraturno


class ExceptionScopeEnum(enum.Enum):
    single_day   = "single_day"
    week         = "week"
    custom_range = "custom_range"


class ScheduleSlotModel(Base):
    __tablename__ = "schedule_slots"

    id                = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id         = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    activity_type     = Column(Enum(ActivityTypeEnum, name="activity_type"), nullable=False,
                               default=ActivityTypeEnum.regular)
    day_of_week       = Column(SmallInteger, nullable=False)  # 1 = Monday
    start_time        = Column(Time, nullable=False)
    end_time          = Column(Time, nullable=False)
    tolerance_minutes = Column(SmallInteger, nullable=False, default=0)

    course = relationship("CourseModel", lazy="joined")

    __table_args__ = (
        CheckConstraint("day_of_week BETWEEN 1 AND 7", name="ck_schedule_slots_day_of_week"),
        CheckConstraint("end_time > start_time", name="ck_schedule_slots_time_order"),
    )


class ScheduleExceptionModel(Base):
    __tablename__ = "schedule_exceptions"

    id             = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id      = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    scope          = Column(Enum(ExceptionScopeEnum, name="exception_scope"), nullable=False)
    exception_date = Column(Date, nullable=True)   # scope = single_day
    week_start     = Column(Date, nullable=True)   # scope = week
    range_start    = Column(Date, nullable=True)   # scope = custom_range
    range_end      = Column(Date, nullable=True)   # scope = custom_range
    day_of_week    = Column(SmallInteger, nullable=True)
    start_time     = Column(Time, nullable=True)
    end_time       = Column(Time, nullable=True)
    reason         = Column(String(255), nullable=True)
    created_by     = Column(String(36), ForeignKey("users.id"), nullable=False)
    created_at     = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        CheckConstraint("day_of_week BETWEEN 1 AND 7", name="ck_schedule_exceptions_day_of_week"),
    )
