from sqlalchemy import Column, Integer, SmallInteger, String, Boolean, Enum, TIMESTAMP, UniqueConstraint
from sqlalchemy.sql import func
from app.infrastructure.database import Base
from app.infrastructure.models.usuario_model import TurnoEnum

class CursoModel(Base):
    __tablename__ = "cursos"

    id           = Column(Integer, primary_key=True)
    anio         = Column(SmallInteger, nullable=False)
    division     = Column(String(10), nullable=False)
    grupo_taller = Column(String(10), nullable=False, default='')
    especialidad = Column(String(100), nullable=True)
    turno        = Column(Enum(TurnoEnum, name="turno"), nullable=False)
    activo       = Column(Boolean, nullable=False, default=True)
    creado_en    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (UniqueConstraint("anio", "division", "grupo_taller", "turno"),)