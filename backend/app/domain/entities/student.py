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
    recursante: bool
    porcentaje_asistencia: float
    # Dimensiones del curso expuestas por separado (además de `curso`, el
    # label compuesto) para que la tabla del frontend pueda filtrar/mostrar
    # año y división como columnas independientes sin tener que parsear el
    # string armado.
    academic_year: int = 0
    grade_year: int = 0
    division: int = 0
    is_active: bool = True
    workshop_group_id: Optional[str] = None
    taller: Optional[str] = None  # group_label legible, si tiene grupo asignado

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
