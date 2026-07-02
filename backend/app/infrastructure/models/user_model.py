import enum
from sqlalchemy import (
    Column, String, Text, Boolean, TIMESTAMP, ForeignKey, Enum,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class UserRoleEnum(enum.Enum):
    direction = "direction"   # dirección — full access
    preceptor = "preceptor"   # assigned courses only


class UserModel(Base):
    __tablename__ = "users"

    id            = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    username      = Column(String(50), nullable=False, unique=True)   # e.g. 'abc.123'
    password_hash = Column(Text, nullable=False)
    full_name     = Column(String(150), nullable=False)
    role          = Column(Enum(UserRoleEnum, name="user_role"), nullable=False)
    is_active     = Column(Boolean, nullable=False, default=True)
    created_by    = Column(String(36), ForeignKey("users.id"), nullable=True)
    created_at    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    updated_at    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    course_assignments = relationship(
        "PreceptorCourseAssignmentModel",
        back_populates="user",
        cascade="all, delete-orphan",
    )


class PreceptorCourseAssignmentModel(Base):
    __tablename__ = "preceptor_course_assignments"

    user_id     = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    course_id   = Column(String(36), ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True)
    is_favorite = Column(Boolean, nullable=False, default=False)
    assigned_at = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    user   = relationship("UserModel", back_populates="course_assignments")
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
