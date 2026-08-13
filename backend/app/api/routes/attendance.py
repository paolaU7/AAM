from datetime import date, datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.attendance_repository_impl import AsistenciaRepositoryImpl
from app.domain.usecases.attendance_usecases import (
    GetRegistrosPorCursoYFecha, GetResumenDiario, GetResumenPorTurno,
    RegistrarIngresoManual, RegistrarRetiroAnticipado, MarcarNoComputable,
    RegistrarAsistenciaError,
)
from app.domain.entities.attendance_record import RegistroAsistencia, ResumenAsistencia


class RegistroResponse(BaseModel):
    id: str
    student_id: str
    student_name: str
    course_id: str
    entry_timestamp: datetime
    source: str
    status: str
    departure_time: Optional[datetime] = None
    departure_reason: Optional[str] = None


class ResumenResponse(BaseModel):
    date: date
    present: int
    absent: int
    late: int
    non_computable_absence: int
    early_departures: int
    total: int


class ManualCheckInCreate(BaseModel):
    student_id: str
    course_id: str
    entry_timestamp: datetime
    status: str  # 'present' | 'late' | 'absent' | 'absent_with_presence'


class EarlyDepartureCreate(BaseModel):
    departure_time: datetime
    reason: str
    registered_by: str  # user id — early_departures.registered_by es NOT NULL


router = APIRouter(prefix="/attendance", tags=["attendance"])


def _registro_response(r: RegistroAsistencia) -> RegistroResponse:
    return RegistroResponse(
        id=r.id, student_id=r.student_id, student_name=r.student_name,
        course_id=r.course_id, entry_timestamp=r.entry_timestamp,
        source=r.source, status=r.status,
        departure_time=r.departure_time, departure_reason=r.departure_reason,
    )


def _resumen_response(r: ResumenAsistencia) -> ResumenResponse:
    return ResumenResponse(
        date=r.date, present=r.present, absent=r.absent, late=r.late,
        non_computable_absence=r.non_computable_absence,
        early_departures=r.early_departures, total=r.total,
    )


@router.get("", response_model=List[RegistroResponse])
def get_registros(course_id: str, fecha: date = Query(..., alias="date"), db: Session = Depends(get_db)):
    repo = AsistenciaRepositoryImpl(db)
    registros = GetRegistrosPorCursoYFecha(repo).execute(course_id, fecha)
    return [_registro_response(r) for r in registros]


@router.get("/summary", response_model=ResumenResponse)
def get_resumen(fecha: date = Query(..., alias="date"), shift: Optional[str] = None, db: Session = Depends(get_db)):
    repo = AsistenciaRepositoryImpl(db)
    if shift:
        resumen = GetResumenPorTurno(repo).execute(shift, fecha)
    else:
        resumen = GetResumenDiario(repo).execute(fecha)
    return _resumen_response(resumen)


@router.post("/manual", response_model=RegistroResponse, status_code=201)
def registrar_ingreso_manual(body: ManualCheckInCreate, db: Session = Depends(get_db)):
    repo = AsistenciaRepositoryImpl(db)
    try:
        registro = RegistrarIngresoManual(repo).execute(
            student_id=body.student_id, course_id=body.course_id,
            entry_timestamp=body.entry_timestamp, status=body.status,
        )
    except RegistrarAsistenciaError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    except ValueError:
        raise HTTPException(status_code=400, detail="Estado inválido.")
    return _registro_response(registro)


@router.post("/{id}/early-departure", response_model=RegistroResponse)
def registrar_retiro_anticipado(id: str, body: EarlyDepartureCreate, db: Session = Depends(get_db)):
    repo = AsistenciaRepositoryImpl(db)
    try:
        registro = RegistrarRetiroAnticipado(repo).execute(
            record_id=id, departure_time=body.departure_time,
            reason=body.reason, registered_by=body.registered_by,
        )
    except RegistrarAsistenciaError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return _registro_response(registro)


@router.post("/{id}/mark-non-computable", response_model=RegistroResponse)
def marcar_no_computable(id: str, db: Session = Depends(get_db)):
    repo = AsistenciaRepositoryImpl(db)
    try:
        registro = MarcarNoComputable(repo).execute(id)
    except RegistrarAsistenciaError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return _registro_response(registro)
