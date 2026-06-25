from sqlalchemy import Column, Integer, String, Boolean, Enum, TIMESTAMP
from sqlalchemy.sql import func
from app.infrastructure.database import Base
import enum

class RolUsuarioEnum(enum.Enum):
    direccion = "direccion"
    preceptor = "preceptor"

class TurnoEnum(enum.Enum):
    manana = "manana"
    tarde = "tarde"
    vespertino = "vespertino"

class UsuarioModel(Base):
    __tablename__ = "usuarios"

    id                = Column(Integer, primary_key=True)
    correo            = Column(String(255), nullable=False, unique=True)
    password_hash     = Column(String(255), nullable=False)
    rol               = Column(Enum(RolUsuarioEnum, name="rol_usuario"), nullable=False)
    nombre            = Column(String(255), nullable=False)
    apellido          = Column(String(255), nullable=False)
    turno             = Column(Enum(TurnoEnum, name="turno"), nullable=True)
    activo            = Column(Boolean, nullable=False, default=True)
    clave_generada_en = Column(TIMESTAMP(timezone=True), nullable=True)
    creado_en         = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())
    actualizado_en    = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())