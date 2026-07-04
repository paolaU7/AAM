from dataclasses import dataclass
from enum import Enum
from typing import Optional

class EstadoRegularidad(str, Enum):
    regular = "regular"
    irregular = "irregular"
    en_riesgo = "en_riesgo"

@dataclass(frozen=True)
class Alumno:
    id: str
    nombre: str
    apellido: str
    dni: str
    curso_id: str
    curso: str
    especialidad: str
    turno: str
    recursante: bool
    porcentaje_asistencia: float

    @property
    def nombre_completo(self) -> str:
        return f"{self.apellido}, {self.nombre}"

    @property
    def estado_regularidad(self) -> EstadoRegularidad:
        if self.porcentaje_asistencia < 65:
            return EstadoRegularidad.en_riesgo
        if self.porcentaje_asistencia < 75:
            return EstadoRegularidad.irregular
        return EstadoRegularidad.regular