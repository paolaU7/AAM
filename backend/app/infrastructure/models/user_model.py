import enum
from sqlalchemy import (
    Column, String, Text, Boolean, TIMESTAMP, ForeignKey, Enum,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class UserRoleEnum(enum.Enum):
    principal = "principal"   # dirección — full access
    preceptor = "preceptor"   # assigned courses only


class UserModel(Base):
    __tablename__ = "users"

    id            = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    email         = Column(String(255), nullable=False, unique=True)
    password_hash = Column(Text, nullable=False)
    full_name     = Column(String(150), nullable=False)
    role          = Column(Enum(UserRoleEnum, name="user_role"), nullable=False)
    is_active     = Column(Boolean, nullable=False, default=True)
    created_by    = Column(String(36), ForeignKey("users.id"), nullable=True)
    created_at    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    updated_at    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())


# NOTE: the real DB has `preceptor_courses` + `preceptor_favorites` as two
# separate bridge tables (matching DATABASE_SCHEMA.md), not a single
# `preceptor_course_assignments` with an `is_favorite` flag. This model still
# points at the old, nonexistent table — dormant/unused (nothing queries it),
# left as known follow-up work, out of scope for the Users CRUD pass.
class PreceptorCourseAssignmentModel(Base):
    __tablename__ = "preceptor_course_assignments"

    user_id     = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    course_id   = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True)
    is_favorite = Column(Boolean, nullable=False, default=False)
    assigned_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    course = relationship("CourseModel", lazy="joined")


class DeviceModel(Base):
    __tablename__ = "devices"

    id           = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    device_name  = Column(String(100), nullable=False, unique=True)
    location     = Column(String(150), nullable=True)
    api_key_hash = Column(Text, nullable=False, unique=True)
    is_active    = Column(Boolean, nullable=False, default=True)
    created_at   = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    last_seen_at = Column(TIMESTAMP(timezone=True), nullable=True)
