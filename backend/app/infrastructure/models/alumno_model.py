from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, ForeignKey
from sqlalchemy.sql import func
from app.infrastructure.database import Base

class AlumnoModel(Base):
    __tablename__ = "alumnos"

    id             = Column(Integer, primary_key=True)
    nombre         = Column(String(255), nullable=False)
    apellido       = Column(String(255), nullable=False)
    dni            = Column(String(20), nullable=False, unique=True)
    curso_id       = Column(Integer, ForeignKey("cursos.id"), nullable=False)
    nfc_uid        = Column(String(64), unique=True, nullable=True)
    qr_token       = Column(String(64), unique=True, nullable=True)
    taller_id      = Column(Integer, ForeignKey("horarios.id"), nullable=True)
    activo         = Column(Boolean, nullable=False, default=True)
    creado_en      = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    actualizado_en = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())