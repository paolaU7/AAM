from sqlalchemy import Column, Integer, String, DateTime, Boolean, UniqueConstraint
from sqlalchemy.orm import declarative_base
from datetime import datetime

Base = declarative_base()


class AsistenciaModel(Base):
    __tablename__ = 'asistencias'
    id = Column(Integer, primary_key=True)
    ulid = Column(String(64), nullable=False, unique=True)
    alumno_dni = Column(String(32), nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    source = Column(String(32), default='device')

    __table_args__ = (UniqueConstraint('ulid', name='uq_asistencia_ulid'),)


class AlumnoModel(Base):
    __tablename__ = 'alumnos'
    id = Column(Integer, primary_key=True)
    nombre = Column(String(120), nullable=False)
    apellido = Column(String(120), nullable=False)
    dni = Column(String(32), nullable=False, unique=True)
    curso = Column(String(64), nullable=False)
    especialidad = Column(String(120), nullable=True)
    recursante = Column(Boolean, default=False)
