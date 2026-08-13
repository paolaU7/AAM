from dataclasses import dataclass
from datetime import datetime, date
from typing import Optional


@dataclass(frozen=True)
class RegistroAsistencia:
    id: str  # ULID
    student_id: str
    student_name: str
    course_id: str
    entry_timestamp: datetime
    source: str    # 'nfc' | 'qr' | 'manual'
    status: str    # 'present' | 'late' | 'absent' | 'absent_with_presence' | 'non_computable_absence'
    departure_time: Optional[datetime] = None
    departure_reason: Optional[str] = None

    @property
    def has_early_departure(self) -> bool:
        return self.departure_time is not None


@dataclass(frozen=True)
class ResumenAsistencia:
    """Absent_with_presence se agrupa junto con absent (así lo define
    DATABASE_SCHEMA.md: cuenta como ausente a efectos de attendance_rate)."""
    date: date
    present: int
    absent: int
    late: int
    non_computable_absence: int
    early_departures: int
    total: int
