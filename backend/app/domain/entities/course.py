from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional

@dataclass(frozen=True)
class Course:
    id: str
    academic_year_id: str
    academic_year: str
    division_id: str
    division: str
    specialty_id: str
    specialty: str
    shift_id: str
    shift: str
    workshop_groups: List[str]
    is_active: bool
    total_students: int = 0
    created_at: Optional[datetime] = None
    shift_start_time: Optional[str] = None
    shift_end_time: Optional[str] = None

    @property
    def name(self) -> str:
        return f"{self.academic_year} {self.division} — {self.specialty} — {self.shift}"

    @property
    def horario(self) -> str:
        if self.shift_start_time and self.shift_end_time:
            return f"{self.shift_start_time} – {self.shift_end_time}"
        return self.shift


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
