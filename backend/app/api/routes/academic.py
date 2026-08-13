from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.academic_repository_impl import SubjectRepositoryImpl, TeacherRepositoryImpl
from app.domain.usecases.academic_usecases import (
    GetSubjects, CreateSubject, GetTeachers, CreateTeacher, AcademicError,
)


class SubjectResponse(BaseModel):
    id: str
    name: str


class SubjectCreate(BaseModel):
    name: str


class TeacherResponse(BaseModel):
    id: str
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None


class TeacherCreate(BaseModel):
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None


router = APIRouter(tags=["academic"])


@router.get("/subjects", response_model=List[SubjectResponse])
def get_subjects(db: Session = Depends(get_db)):
    repo = SubjectRepositoryImpl(db)
    return [SubjectResponse(id=s.id, name=s.name) for s in GetSubjects(repo).execute()]


@router.post("/subjects", response_model=SubjectResponse, status_code=201)
def create_subject(body: SubjectCreate, db: Session = Depends(get_db)):
    repo = SubjectRepositoryImpl(db)
    try:
        s = CreateSubject(repo).execute(body.name)
    except AcademicError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return SubjectResponse(id=s.id, name=s.name)


@router.get("/teachers", response_model=List[TeacherResponse])
def get_teachers(db: Session = Depends(get_db)):
    repo = TeacherRepositoryImpl(db)
    return [
        TeacherResponse(id=t.id, full_name=t.full_name, email=t.email, phone=t.phone)
        for t in GetTeachers(repo).execute()
    ]


@router.post("/teachers", response_model=TeacherResponse, status_code=201)
def create_teacher(body: TeacherCreate, db: Session = Depends(get_db)):
    repo = TeacherRepositoryImpl(db)
    try:
        t = CreateTeacher(repo).execute(body.full_name, email=body.email, phone=body.phone)
    except AcademicError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return TeacherResponse(id=t.id, full_name=t.full_name, email=t.email, phone=t.phone)
