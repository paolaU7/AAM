from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.infrastructure.database import get_db
from app.infrastructure.repositories.curso_repository_impl import CursoRepositoryImpl
from app.domain.usecases.curso_usecases import GetCursos, GetCursoPorId, GetCursosPorTurno
from pydantic import BaseModel

class CursoResponse(BaseModel):
    id: str
    anio: int
    division: str
    grupo_taller: str
    especialidad: str
    turno: str
    total_alumnos: int
    nombre: str
    horario: str

    class Config:
        from_attributes = True

router = APIRouter(prefix="/cursos", tags=["cursos"])

@router.get("", response_model=List[CursoResponse])
def get_cursos(db: Session = Depends(get_db)):
    repo = CursoRepositoryImpl(db)
    cursos = GetCursos(repo).execute()
    return [CursoResponse(
        id=c.id, anio=c.anio, division=c.division,
        grupo_taller=c.grupo_taller, especialidad=c.especialidad,
        turno=c.turno, total_alumnos=c.total_alumnos,
        nombre=c.nombre, horario=c.horario
    ) for c in cursos]

@router.get("/{id}", response_model=CursoResponse)
def get_curso(id: str, db: Session = Depends(get_db)):
    repo = CursoRepositoryImpl(db)
    curso = GetCursoPorId(repo).execute(id)
    if not curso:
        raise HTTPException(status_code=404, detail="Curso no encontrado")
    return CursoResponse(
        id=curso.id, anio=curso.anio, division=curso.division,
        grupo_taller=curso.grupo_taller, especialidad=curso.especialidad,
        turno=curso.turno, total_alumnos=curso.total_alumnos,
        nombre=curso.nombre, horario=curso.horario
    )

@router.get("/turno/{turno}", response_model=List[CursoResponse])
def get_cursos_por_turno(turno: str, db: Session = Depends(get_db)):
    repo = CursoRepositoryImpl(db)
    cursos = GetCursosPorTurno(repo).execute(turno)
    return [CursoResponse(
        id=c.id, anio=c.anio, division=c.division,
        grupo_taller=c.grupo_taller, especialidad=c.especialidad,
        turno=c.turno, total_alumnos=c.total_alumnos,
        nombre=c.nombre, horario=c.horario
    ) for c in cursos]