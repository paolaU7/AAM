from datetime import time
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.workshop_group_repository_impl import WorkshopGroupRepositoryImpl
from app.infrastructure.repositories.time_slot_repository_impl import TimeSlotRepositoryImpl
from app.domain.usecases.time_slot_usecases import GetTimeSlotsByWorkshopGroup


class WorkshopGroupResponse(BaseModel):
    id: str
    course_id: str
    group_label: str

    class Config:
        from_attributes = True


class TimeSlotResponse(BaseModel):
    id: str
    course_id: Optional[str] = None
    workshop_group_id: Optional[str] = None
    shift: str
    activity_type: str
    day_of_week: int
    start_time: time
    end_time: time
    late_tolerance_minutes: int


router = APIRouter(tags=["workshop-groups"])


def _to_response(w) -> WorkshopGroupResponse:
    return WorkshopGroupResponse(
        id=str(w.id), course_id=str(w.course_id), group_label=w.group_label,
    )


@router.get("/workshop-groups", response_model=List[WorkshopGroupResponse])
def get_workshop_groups(db: Session = Depends(get_db)):
    """Catálogo completo — sin filtrar por curso. Usado hoy por Horarios
    (filtro independiente); Alumnos usa el endpoint scoped de abajo."""
    repo = WorkshopGroupRepositoryImpl(db)
    return [_to_response(w) for w in repo.get_all()]


@router.get("/courses/{course_id}/workshop-groups", response_model=List[WorkshopGroupResponse])
def get_workshop_groups_by_course(course_id: str, db: Session = Depends(get_db)):
    """Grupos de taller de UN curso puntual — son una subdivisión interna
    del curso, no se comparten entre cursos distintos."""
    repo = WorkshopGroupRepositoryImpl(db)
    return [_to_response(w) for w in repo.get_by_course(course_id)]


@router.get("/workshop-groups/{id}/time-slots", response_model=List[TimeSlotResponse])
def get_workshop_group_time_slots(id: str, db: Session = Depends(get_db)):
    repo = TimeSlotRepositoryImpl(db)
    slots = GetTimeSlotsByWorkshopGroup(repo).execute(id)
    return [
        TimeSlotResponse(
            id=s.id, course_id=s.course_id, workshop_group_id=s.workshop_group_id,
            shift=s.shift, activity_type=s.activity_type, day_of_week=s.day_of_week,
            start_time=s.start_time, end_time=s.end_time,
            late_tolerance_minutes=s.late_tolerance_minutes,
        )
        for s in slots
    ]
