from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
import io
import openpyxl
from app.infrastructure.database import get_db
from app.infrastructure.repositories.student_repository_impl import AlumnoRepositoryImpl
from app.infrastructure.repositories.course_repository_impl import CourseRepositoryImpl
from app.infrastructure.repositories.workshop_group_repository_impl import WorkshopGroupRepositoryImpl
from app.domain.usecases.student_usecases import (
    GetAlumnos, GetAlumnoPorId, ActualizarAlumno, CrearAlumnoManual, AltaAlumnoError,
)
from app.domain.usecases.student_import_usecases import (
    ImportarAlumnosExcel, ImportarAlumnosExcelError,
)
from app.domain.entities.student import Alumno
from pydantic import BaseModel

class AlumnoResponse(BaseModel):
    id: str
    nombre: str
    apellido: str
    nombre_completo: str
    dni: str
    curso_id: str
    curso: str
    recursante: bool
    porcentaje_asistencia: float
    estado_regularidad: str
    workshop_group_id: Optional[str] = None
    taller: Optional[str] = None

class AlumnoCreate(BaseModel):
    # El curso ya viene resuelto del frontend (cascada año lectivo -> año de
    # cursada -> división contra /courses); acá solo se recibe el course_id.
    # workshop_group_id es opcional y debe pertenecer a ese mismo curso.
    first_name: str
    last_name: str
    national_id: str
    course_id: str
    workshop_group_id: Optional[str] = None

class AlumnoUpdate(BaseModel):
    nombre: str
    apellido: str
    dni: str
    curso_id: str
    workshop_group_id: Optional[str] = None

class ImportRowErrorResponse(BaseModel):
    fila: int
    motivo: str

class ImportReportResponse(BaseModel):
    curso_id: str
    total_filas: int
    creados: int
    errores: List[ImportRowErrorResponse]

router = APIRouter(prefix="/alumnos", tags=["alumnos"])

def _to_response(a: Alumno) -> AlumnoResponse:
    return AlumnoResponse(
        id=str(a.id), nombre=a.nombre, apellido=a.apellido,
        nombre_completo=a.nombre_completo, dni=a.dni,
        curso_id=str(a.curso_id), curso=a.curso,
        recursante=a.recursante,
        porcentaje_asistencia=a.porcentaje_asistencia,
        estado_regularidad=a.estado_regularidad.value,
        workshop_group_id=a.workshop_group_id,
        taller=a.taller,
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
    alumno_repo = AlumnoRepositoryImpl(db)
    course_repo = CourseRepositoryImpl(db)
    workshop_group_repo = WorkshopGroupRepositoryImpl(db)
    try:
        alumno = CrearAlumnoManual(alumno_repo, course_repo, workshop_group_repo).execute(
            first_name=body.first_name,
            last_name=body.last_name,
            national_id=body.national_id,
            course_id=body.course_id,
            workshop_group_id=body.workshop_group_id,
        )
    except AltaAlumnoError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return _to_response(alumno)

@router.post("/import-excel", response_model=ImportReportResponse)
async def importar_alumnos_excel(file: UploadFile = File(...), db: Session = Depends(get_db)):
    """Importación masiva de alumnos para UN curso. Formato esperado (mismo que
    la plantilla 'Curso_con_alumnos'):
      B1 = Año lectivo (ej. 2026)
      B2 = Año de cursada (ej. 4)
      B3 = División (ej. 2)
      Fila 5 = encabezados de columna (#, Dni, Nombre/s, Apellido/s, Grupo de taller)
      Fila 6 en adelante = datos de alumnos
    No aborta el archivo entero ante un error de fila: reporta fila por fila.
    """
    if not file.filename or not file.filename.lower().endswith((".xlsx", ".xlsm")):
        raise HTTPException(status_code=400, detail="El archivo debe ser un Excel (.xlsx).")

    contents = await file.read()
    try:
        wb = openpyxl.load_workbook(io.BytesIO(contents), data_only=True)
        ws = wb.active
    except Exception:
        raise HTTPException(status_code=400, detail="No se pudo leer el archivo. ¿Es un .xlsx válido?")

    def cell(row: int, col: int):
        return ws.cell(row=row, column=col).value

    academic_year_raw = cell(1, 2)
    grade_year_raw = cell(2, 2)
    division_raw = cell(3, 2)

    if academic_year_raw is None or grade_year_raw is None or division_raw is None:
        raise HTTPException(
            status_code=400,
            detail="Faltan datos en el encabezado (Año lectivo, Año de cursada o División). "
                   "Revisá las primeras filas de la plantilla.",
        )

    def _as_int(value, field_name: str) -> int:
        try:
            return int(value)
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail=f"El '{field_name}' del encabezado no es un número válido.")

    academic_year = _as_int(academic_year_raw, "Año lectivo")
    grade_year = _as_int(grade_year_raw, "Año de cursada")
    division = _as_int(division_raw, "División")

    def _as_text(value) -> str:
        # Excel suele guardar "4" como float 4.0; lo normalizamos a "4".
        if isinstance(value, float) and value.is_integer():
            return str(int(value))
        return str(value).strip()

    # Datos de alumnos: arrancan en la fila 6 (1-indexed), se cortan en la
    # primera fila donde la columna "#" viene vacía.
    rows = []
    fila = 6
    while True:
        numero = cell(fila, 1)
        if numero is None:
            break
        rows.append({
            "fila": fila,
            "dni": _as_text(cell(fila, 2)) if cell(fila, 2) is not None else "",
            "nombre": cell(fila, 3),
            "apellido": cell(fila, 4),
            "grupo_taller": cell(fila, 5),
        })
        fila += 1

    alumno_repo = AlumnoRepositoryImpl(db)
    course_repo = CourseRepositoryImpl(db)
    workshop_group_repo = WorkshopGroupRepositoryImpl(db)
    try:
        report = ImportarAlumnosExcel(alumno_repo, course_repo, workshop_group_repo).execute(
            academic_year=academic_year,
            grade_year=grade_year,
            division=division,
            rows=rows,
        )
    except ImportarAlumnosExcelError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))

    return ImportReportResponse(
        curso_id=str(report.curso_id),
        total_filas=report.total_filas,
        creados=len(report.creados),
        errores=[
            ImportRowErrorResponse(fila=e.fila, motivo=e.motivo or "")
            for e in report.errores
        ],
    )


@router.put("/{id}", response_model=AlumnoResponse)
def actualizar_alumno(id: str, body: AlumnoUpdate, db: Session = Depends(get_db)):
    repo = AlumnoRepositoryImpl(db)
    alumno = Alumno(
        id=id, nombre=body.nombre, apellido=body.apellido,
        dni=body.dni, curso_id=body.curso_id, curso="",
        recursante=False, porcentaje_asistencia=0.0,
        workshop_group_id=body.workshop_group_id,
    )
    result = ActualizarAlumno(repo).execute(id, alumno)
    if not result:
        raise HTTPException(status_code=404, detail="Alumno no encontrado")
    return _to_response(result)
