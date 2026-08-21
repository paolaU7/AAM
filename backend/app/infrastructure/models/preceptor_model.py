from sqlalchemy import Column, String, Text, TIMESTAMP, Date, ForeignKey, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base
from app.infrastructure.models.schedule_model import ShiftTypeEnum


class CoursePreceptorModel(Base):
    """Preceptor a cargo PERMANENTE de un curso, por turno."""
    __tablename__ = "course_preceptors"

    course_id    = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True)
    shift        = Column(Enum(ShiftTypeEnum, name="shift_type"), primary_key=True)
    preceptor_id = Column(String(36), ForeignKey("users.id"), nullable=False)

    preceptor = relationship("UserModel", foreign_keys=[preceptor_id], lazy="joined")


class CoursePreceptorTempAssignmentModel(Base):
    """Reemplazo TEMPORAL, máximo 1 mes (CHECK en la base)."""
    __tablename__ = "course_preceptor_temp_assignments"

    id           = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    course_id    = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    shift        = Column(Enum(ShiftTypeEnum, name="shift_type"), nullable=False)
    preceptor_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    start_date   = Column(Date, nullable=False)
    end_date     = Column(Date, nullable=False)
    reason       = Column(Text, nullable=True)
    created_by   = Column(String(36), ForeignKey("users.id"), nullable=False)
    created_at   = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    preceptor = relationship("UserModel", foreign_keys=[preceptor_id], lazy="joined")
