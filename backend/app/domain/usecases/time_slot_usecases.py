from datetime import time
from typing import List
from app.domain.entities.time_slot import TimeSlot
from app.domain.repositories.time_slot_repository import TimeSlotRepository


class TimeSlotError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class GetTimeSlotsByCourse:
    def __init__(self, repo: TimeSlotRepository):
        self.repo = repo

    def execute(self, course_id: str) -> List[TimeSlot]:
        return self.repo.get_by_course(course_id)


class GetTimeSlotsByWorkshopGroup:
    def __init__(self, repo: TimeSlotRepository):
        self.repo = repo

    def execute(self, workshop_group_id: str) -> List[TimeSlot]:
        return self.repo.get_by_workshop_group(workshop_group_id)


class CreateCourseTimeSlot:
    """Crea una franja del TURNO PRINCIPAL (curricular o contraturno) de un
    curso — no de un grupo de taller, eso se maneja aparte."""

    def __init__(self, repo: TimeSlotRepository):
        self.repo = repo

    def execute(
        self, *, course_id: str, shift: str, activity_type: str,
        day_of_week: int, start_time: time, end_time: time,
        late_tolerance_minutes: int = 0,
    ) -> TimeSlot:
        if activity_type not in ("main_shift", "after_shift"):
            raise TimeSlotError("activity_type debe ser 'main_shift' o 'after_shift' para el turno principal.", 400)
        if day_of_week < 1 or day_of_week > 7:
            raise TimeSlotError("day_of_week debe estar entre 1 y 7.", 400)
        if end_time <= start_time:
            raise TimeSlotError("La hora de fin debe ser posterior a la de inicio.", 400)

        return self.repo.create(
            course_id=course_id, workshop_group_id=None,
            shift=shift, activity_type=activity_type,
            day_of_week=day_of_week, start_time=start_time, end_time=end_time,
            late_tolerance_minutes=late_tolerance_minutes,
        )


class DeleteTimeSlot:
    def __init__(self, repo: TimeSlotRepository):
        self.repo = repo

    def execute(self, id: str) -> bool:
        return self.repo.delete(id)
