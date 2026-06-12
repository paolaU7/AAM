from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Asistencia:
    id: Optional[int]
    ulid: str
    alumno_dni: Optional[str]
    timestamp: datetime
    source: str = "device"
