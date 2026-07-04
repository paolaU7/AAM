from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional

class MetodoIngreso(str, Enum):
    nfc = "nfc"
    qr = "qr"
    manual = "manual"
    desconocido = "desconocido"

class EstadoAsistencia(str, Enum):
    presente = "presente"
    ausente = "ausente"
    tardanza = "tardanza"
    no_computable = "no_computable"

@dataclass(frozen=True)
class RegistroAsistencia:
    id: str
    alumno_id: str
    alumno_nombre: str
    curso_id: str
    fecha: datetime
    metodo_ingreso: MetodoIngreso
    estado: EstadoAsistencia
    hora_ingreso: Optional[datetime] = None
    hora_retiro: Optional[datetime] = None
    motivo_retiro: Optional[str] = None
    es_no_computable: bool = False
    motivo_no_computable: Optional[str] = None

    @property
    def tiene_retiro_anticipado(self) -> bool:
        return self.hora_retiro is not None
    