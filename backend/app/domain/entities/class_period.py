from dataclasses import dataclass
from datetime import time
from typing import Optional


@dataclass(frozen=True)
class ClassPeriod:
    """Un período dentro del horario académico DETALLADO día por día de un
    curso (clase con materia+profesor, recreo o almuerzo). Distinto de
    TimeSlot: esto es solo para armar/mostrar la grilla completa, no
    dispara asistencia por período individual."""

    id: str
    course_id: str
    day_of_week: int   # ISO 1..7
    shift: str          # 'morning' | 'afternoon' | 'evening'
    period_order: int   # posición dentro del día (1, 2, 3...)
    period_type: str    # 'class' | 'recess' | 'lunch'
    start_time: time
    end_time: time
    is_fifth_module: bool = False
    subject_id: Optional[str] = None
    subject_name: Optional[str] = None
    teacher_id: Optional[str] = None
    teacher_name: Optional[str] = None
