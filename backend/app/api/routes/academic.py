from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.academic_repository_impl import (
    SubjectRepositoryImpl, SubjectApplicabilityRepositoryImpl,
    TeacherRepositoryImpl, CourseSubjectTeacherRepositoryImpl,
)
from app.infrastructure.repositories.specialty_repository_impl import SpecialtyRepositoryImpl
from app.domain.usecases.academic_usecases import (
    GetSubjects, CreateSubject, GetSubjectApplicability, AddSubjectApplicability, RemoveSubjectApplicability,
    GetTeachers, CreateTeacher, GetTeacherAssignments, AcademicError,
)


class SubjectResponse(BaseModel):
    id: str
    name: str
    subject_type: str


class SubjectCreate(BaseModel):
    name: str
    subject_type: str  # 'curricular' | 'workshop' — fijo, no se puede cambiar después


class SubjectApplicabilityResponse(BaseModel):
    id: str
    subject_id: str
    grade_year: int
    specialty_id: str
    specialty_name: str


class SubjectApplicabilityCreate(BaseModel):
    grade_year: int
    specialty_id: str


class TeacherResponse(BaseModel):
    id: str
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None


class TeacherCreate(BaseModel):
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None


class TeacherAssignmentResponse(BaseModel):
    course_id: str
    course_name: Optional[str] = None
    subject_id: str
    subject_name: str
    subject_type: str
    teacher_id: str
    teacher_name: str


router = APIRouter(tags=["academic"])


@router.get("/subjects", response_model=List[SubjectResponse])
def get_subjects(grade_year: Optional[int] = None, specialty_id: Optional[str] = None, db: Session = Depends(get_db)):
    """Sin filtros: catálogo completo (pantalla Materias). Con
    grade_year+specialty_id: solo lo habilitado para esa combinación —
    lo que alimenta el desplegable al armar el horario de un curso."""
    repo = SubjectRepositoryImpl(db)
    rows = GetSubjects(repo).execute(grade_year=grade_year, specialty_id=specialty_id)
    return [SubjectResponse(id=s.id, name=s.name, subject_type=s.subject_type) for s in rows]


@router.post("/subjects", response_model=SubjectResponse, status_code=201)
def create_subject(body: SubjectCreate, db: Session = Depends(get_db)):
    repo = SubjectRepositoryImpl(db)
    try:
        s = CreateSubject(repo).execute(body.name, body.subject_type)
    except AcademicError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return SubjectResponse(id=s.id, name=s.name, subject_type=s.subject_type)


@router.get("/subjects/{id}/applicability", response_model=List[SubjectApplicabilityResponse])
def get_subject_applicability(id: str, db: Session = Depends(get_db)):
    repo = SubjectApplicabilityRepositoryImpl(db)
    rows = GetSubjectApplicability(repo).execute(id)
    return [SubjectApplicabilityResponse(**r.__dict__) for r in rows]


@router.post("/subjects/{id}/applicability", response_model=SubjectApplicabilityResponse, status_code=201)
def add_subject_applicability(id: str, body: SubjectApplicabilityCreate, db: Session = Depends(get_db)):
    repo = SubjectApplicabilityRepositoryImpl(db)
    subject_repo = SubjectRepositoryImpl(db)
    specialty_repo = SpecialtyRepositoryImpl(db)
    try:
        row = AddSubjectApplicability(repo, subject_repo, specialty_repo).execute(
            subject_id=id, grade_year=body.grade_year, specialty_id=body.specialty_id,
        )
    except AcademicError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return SubjectApplicabilityResponse(**row.__dict__)


@router.delete("/subjects/{id}/applicability/{applicability_id}", status_code=204)
def remove_subject_applicability(id: str, applicability_id: str, db: Session = Depends(get_db)):
    repo = SubjectApplicabilityRepositoryImpl(db)
    ok = RemoveSubjectApplicability(repo).execute(applicability_id)
    if not ok:
        raise HTTPException(status_code=404, detail="No encontrado")
    return None


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


@router.get("/teachers/{id}/assignments", response_model=List[TeacherAssignmentResponse])
def get_teacher_assignments(id: str, db: Session = Depends(get_db)):
    """Curso + materia de todas las asignaciones de ESE profesor — para la
    ficha de Profes. No distingue grupo de taller ni reemplazos puntuales
    (eso vive en class_periods, no acá)."""
    repo = CourseSubjectTeacherRepositoryImpl(db)
    rows = GetTeacherAssignments(repo).execute(id)
    return [
        TeacherAssignmentResponse(
            course_id=r.course_id, course_name=r.course_name,
            subject_id=r.subject_id, subject_name=r.subject_name, subject_type=r.subject_type,
            teacher_id=r.teacher_id, teacher_name=r.teacher_name,
        )
        for r in rows
    ]
