from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.workshop_group_repository_impl import WorkshopGroupRepositoryImpl


class WorkshopGroupResponse(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True


class AddWorkshopGroupBody(BaseModel):
    workshop_group_id: int


router = APIRouter(tags=["workshop-groups"])


@router.get("/workshop-groups", response_model=List[WorkshopGroupResponse])
def get_workshop_groups(db: Session = Depends(get_db)):
    repo = WorkshopGroupRepositoryImpl(db)
    return [WorkshopGroupResponse(id=w.id, name=w.name) for w in repo.get_all()]


@router.get("/students/{student_id}/workshop-groups", response_model=List[WorkshopGroupResponse])
def get_student_workshop_groups(student_id: str, db: Session = Depends(get_db)):
    repo = WorkshopGroupRepositoryImpl(db)
    groups = repo.get_for_student(student_id)
    if groups is None:
        raise HTTPException(status_code=404, detail="Student not found")
    return [WorkshopGroupResponse(id=w.id, name=w.name) for w in groups]


@router.post("/students/{student_id}/workshop-groups", response_model=List[WorkshopGroupResponse], status_code=201)
def add_student_workshop_group(student_id: str, body: AddWorkshopGroupBody, db: Session = Depends(get_db)):
    repo = WorkshopGroupRepositoryImpl(db)
    ok = repo.add_to_student(student_id, body.workshop_group_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Student or workshop group not found")
    return [WorkshopGroupResponse(id=w.id, name=w.name) for w in repo.get_for_student(student_id)]


@router.delete("/students/{student_id}/workshop-groups/{workshop_group_id}", status_code=204)
def remove_student_workshop_group(student_id: str, workshop_group_id: int, db: Session = Depends(get_db)):
    repo = WorkshopGroupRepositoryImpl(db)
    ok = repo.remove_from_student(student_id, workshop_group_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Student not found")
    return None
