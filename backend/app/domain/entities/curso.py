from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass(frozen=True)
class Curso:
    id: str
    anio: int
    division: str
    especialidad: str
    turno: str
    total_alumnos: int
    grupo_taller: str = ''
    preceptor_id: Optional[str] = None
    horario_ingreso: Optional[str] = None
    horario_egreso: Optional[str] = None

    @property
    def nombre(self) -> str:
        return f"{self.anio}° {self.division}° {self.grupo_taller} — {self.especialidad}"

    @property
    def horario(self) -> str:
        if self.horario_ingreso and self.horario_egreso:
            return f"{self.horario_ingreso} – {self.horario_egreso}"
        return ''


@dataclass(frozen=True)
class ResumenAsistencia:
    fecha: datetime
    presentes: int
    ausentes: int
    tardanzas: int
    no_computables: int
    retiros: int
    total: int

    @property
    def porcentaje_asistencia(self) -> float:
        return (self.presentes / self.total) * 100 if self.total > 0 else 0.0