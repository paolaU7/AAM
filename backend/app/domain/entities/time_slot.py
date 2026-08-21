from dataclasses import dataclass
from datetime import time
from typing import Optional


@dataclass(frozen=True)
class TimeSlot:
    """Recurring weekly time slot for a course OR a workshop group —
    exactly one of course_id / workshop_group_id is set."""

    id: str
    shift: str            # 'morning' | 'afternoon' | 'evening'
    activity_type: str    # 'main_shift' | 'workshop' | 'after_shift'
    day_of_week: int       # ISO: 1 = Monday .. 7 = Sunday
    start_time: time
    end_time: time
    late_tolerance_minutes: int = 0
    course_id: Optional[str] = None
    workshop_group_id: Optional[str] = None
