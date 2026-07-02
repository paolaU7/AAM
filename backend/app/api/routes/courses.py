from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.infrastructure.database import get_db
from app.infrastructure.repositories.course_repository_impl import CourseRepositoryImpl
from app.domain.usecases.course_usecases import GetCourses, GetCourseById, GetCoursesByShift
from pydantic import BaseModel

class CourseResponse(BaseModel):
    id: str
    anio: str
    division: str
    grupo_taller: str
    workshop_groups: List[str]
    especialidad: str
    turno: str
    total_alumnos: int
    nombre: str
    horario: str

    class Config:
        from_attributes = True

router = APIRouter(prefix="/courses", tags=["courses"])

@router.get("", response_model=List[CourseResponse])
def get_courses(db: Session = Depends(get_db)):
    repo = CourseRepositoryImpl(db)
    cursos = GetCourses(repo).execute()
    return [CourseResponse(
        id=c.id,
        anio=c.academic_year,
        division=c.division,
        grupo_taller=", ".join(c.workshop_groups),
        workshop_groups=c.workshop_groups,
        especialidad=c.specialty,
        turno=c.shift,
        total_alumnos=c.total_students,
        nombre=c.name,
        horario=c.horario
    ) for c in cursos]

@router.get("/{id}", response_model=CourseResponse)
def get_course(id: str, db: Session = Depends(get_db)):
    repo = CourseRepositoryImpl(db)
    curso = GetCourseById(repo).execute(id)
    if not curso:
        raise HTTPException(status_code=404, detail="Course not found")
    return CourseResponse(
        id=curso.id,
        anio=curso.academic_year,
        division=curso.division,
        grupo_taller=", ".join(curso.workshop_groups),
        workshop_groups=curso.workshop_groups,
        especialidad=curso.specialty,
        turno=curso.shift,
        total_alumnos=curso.total_students,
        nombre=curso.name,
        horario=curso.horario
    )

@router.get("/shift/{shift_name}", response_model=List[CourseResponse])
def get_courses_by_shift(shift_name: str, db: Session = Depends(get_db)):
    repo = CourseRepositoryImpl(db)
    cursos = GetCoursesByShift(repo).execute(shift_name)
    return [CourseResponse(
        id=c.id,
        anio=c.academic_year,
        division=c.division,
        grupo_taller=", ".join(c.workshop_groups),
        workshop_groups=c.workshop_groups,
        especialidad=c.specialty,
        turno=c.shift,
        total_alumnos=c.total_students,
        nombre=c.name,
        horario=c.horario
    ) for c in cursos]
