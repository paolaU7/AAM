from datetime import time
from typing import List, Optional
from app.domain.entities.class_period import ClassPeriod
from app.domain.repositories.class_period_repository import ClassPeriodRepository


class ClassPeriodError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class GetClassPeriodsByCourse:
    def __init__(self, repo: ClassPeriodRepository):
        self.repo = repo

    def execute(self, course_id: str) -> List[ClassPeriod]:
        return self.repo.get_by_course(course_id)


class CreateClassPeriod:
    def __init__(self, repo: ClassPeriodRepository):
        self.repo = repo

    def execute(
        self,
        *,
        course_id: str,
        day_of_week: int,
        shift: str,
        period_type: str,
        start_time: time,
        end_time: time,
        subject_id: Optional[str] = None,
        teacher_id: Optional[str] = None,
        is_fifth_module: bool = False,
    ) -> ClassPeriod:
        if day_of_week < 1 or day_of_week > 7:
            raise ClassPeriodError("day_of_week debe estar entre 1 y 7.", 400)
        if end_time <= start_time:
            raise ClassPeriodError("La hora de fin debe ser posterior a la de inicio.", 400)
        if period_type == "class" and not subject_id:
            raise ClassPeriodError("Un período de clase necesita una materia.", 400)
        if period_type in ("recess", "lunch") and (subject_id or teacher_id):
            raise ClassPeriodError("Recreo y almuerzo no llevan materia ni profesor.", 400)

        return self.repo.create(
            course_id=course_id, day_of_week=day_of_week, shift=shift, period_type=period_type,
            start_time=start_time, end_time=end_time,
            subject_id=subject_id, teacher_id=teacher_id, is_fifth_module=is_fifth_module,
        )


class DeleteClassPeriod:
    def __init__(self, repo: ClassPeriodRepository):
        self.repo = repo

    def execute(self, id: str) -> bool:
        return self.repo.delete(id)
