from sqlalchemy import Column, String, Boolean, TIMESTAMP, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class StudentModel(Base):
    __tablename__ = "students"

    id                   = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    first_name           = Column(String(100), nullable=False)
    last_name            = Column(String(100), nullable=False)
    document_number      = Column(String(20), unique=True, nullable=True)   # DNI, optional but unique if set
    course_id            = Column(String(36), ForeignKey("courses.id"), nullable=False)
    workshop_group_id    = Column(String(36), ForeignKey("workshop_groups.id"), nullable=True)  # 1 grupo, dentro de su curso
    is_repeating_student = Column(Boolean, nullable=False, default=False)
    created_at           = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    updated_at           = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    course = relationship("CourseModel", lazy="joined")
    workshop_group = relationship("WorkshopGroupModel", lazy="joined")
