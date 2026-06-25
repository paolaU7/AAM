from sqlalchemy import Column, Integer, String, Boolean, Enum, TIMESTAMP, ForeignKey, Text
from app.infrastructure.database import Base
import enum

class MetodoRegistroEnum(enum.Enum):
    nfc    = "nfc"
    qr     = "qr"
    manual = "manual"

class EstadoAsistenciaEnum(enum.Enum):
    presente              = "presente"
    tarde                 = "tarde"
    ausente               = "ausente"
    ausente_con_permanencia = "ausente_con_permanencia"
    falta_no_computable   = "falta_no_computable"

class TipoActividadEnum(enum.Enum):
    turno_principal = "turno_principal"
    taller          = "taller"
    contraturno     = "contraturno"

class RegistroIngresoModel(Base):
    __tablename__ = "registros_ingreso"

    ulid                     = Column(String(26), primary_key=True)
    alumno_id                = Column(Integer, ForeignKey("alumnos.id"), nullable=False)
    dispositivo_id           = Column(Integer, ForeignKey("dispositivos.id"), nullable=True)
    tipo_actividad           = Column(Enum(TipoActividadEnum, name="tipo_actividad"), nullable=False)
    metodo                   = Column(Enum(MetodoRegistroEnum, name="metodo_registro"), nullable=False)
    registrado_en            = Column(TIMESTAMP(timezone=True), nullable=False)
    sincronizado_en          = Column(TIMESTAMP(timezone=True), nullable=True)
    creado_por               = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    estado                   = Column(Enum(EstadoAsistenciaEnum, name="estado_asistencia"), nullable=True)
    es_falta_no_computable   = Column(Boolean, nullable=False, default=False)
    motivo_no_computable     = Column(Text, nullable=True)
    no_computable_automatico = Column(Boolean, nullable=False, default=False)
    