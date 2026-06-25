from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.infrastructure.database import get_db
from app.infrastructure.repositories.alumno_repository_impl import AlumnoRepositoryImpl
from app.domain.usecases.alumno_usecases import GetAlumnos, GetAlumnoPorId, CrearAlumno, ActualizarAlumno
from app.domain.entities.alumno import Alumno
from pydantic import BaseModel

class AlumnoResponse(BaseModel):
    id: str
    nombre: str
    apellido: str
    nombre_completo: str
    dni: str
    curso_id: str
    curso: str
    especialidad: str
    turno: str
    recursante: bool
    porcentaje_asistencia: float
    estado_regularidad: str

class AlumnoCreate(BaseModel):
    nombre: str
    apellido: str
    dni: str
    curso_id: str

class AlumnoUpdate(BaseModel):
    nombre: str
    apellido: str
    dni: str
    curso_id: str

router = APIRouter(prefix="/alumnos", tags=["alumnos"])

def _to_response(a: Alumno) -> AlumnoResponse:
    return AlumnoResponse(
        id=a.id, nombre=a.nombre, apellido=a.apellido,
        nombre_completo=a.nombre_completo, dni=a.dni,
        curso_id=a.curso_id, curso=a.curso, especialidad=a.especialidad,
        turno=a.turno, recursante=a.recursante,
        porcentaje_asistencia=a.porcentaje_asistencia,
        estado_regularidad=a.estado_regularidad.value
    )

@router.get("", response_model=List[AlumnoResponse])
def get_alumnos(db: Session = Depends(get_db)):
    repo = AlumnoRepositoryImpl(db)
    return [_to_response(a) for a in GetAlumnos(repo).execute()]

@router.get("/{id}", response_model=AlumnoResponse)
def get_alumno(id: str, db: Session = Depends(get_db)):
    repo = AlumnoRepositoryImpl(db)
    alumno = GetAlumnoPorId(repo).execute(id)
    if not alumno:
        raise HTTPException(status_code=404, detail="Alumno no encontrado")
    return _to_response(alumno)

@router.post("", response_model=AlumnoResponse, status_code=201)
def crear_alumno(body: AlumnoCreate, db: Session = Depends(get_db)):
    repo = AlumnoRepositoryImpl(db)
    alumno = Alumno(
        id="", nombre=body.nombre, apellido=body.apellido,
        dni=body.dni, curso_id=body.curso_id, curso="",
        especialidad="", turno="", recursante=False,
        porcentaje_asistencia=0.0
    )
    return _to_response(CrearAlumno(repo).execute(alumno))

@router.put("/{id}", response_model=AlumnoResponse)
def actualizar_alumno(id: str, body: AlumnoUpdate, db: Session = Depends(get_db)):
    repo = AlumnoRepositoryImpl(db)
    alumno = Alumno(
        id=id, nombre=body.nombre, apellido=body.apellido,
        dni=body.dni, curso_id=body.curso_id, curso="",
        especialidad="", turno="", recursante=False,
        porcentaje_asistencia=0.0
    )
    result = ActualizarAlumno(repo).execute(id, alumno)
    if not result:
        raise HTTPException(status_code=404, detail="Alumno no encontrado")
    return _to_response(result)