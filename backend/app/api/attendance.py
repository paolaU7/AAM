from fastapi import APIRouter, Header, HTTPException, Depends
from pydantic import BaseModel
from app.core.config import settings
from app.infrastructure.repositories.asistencia_repository_impl import AsistenciaRepositoryImpl
from app.domain.usecases.registrar_asistencia import RegistrarAsistencia

router = APIRouter(prefix="/api/attendance", tags=["attendance"])


class AttendanceIn(BaseModel):
    ulid: str
    alumno_dni: str | None = None


def verify_api_key(x_api_key: str | None = Header(default=None)):
    if x_api_key != settings.api_key_device:
        raise HTTPException(status_code=401, detail="Invalid API Key")


@router.post("/register")
async def register_attendance(payload: AttendanceIn, _=Depends(verify_api_key)):
    repo = AsistenciaRepositoryImpl()
    usecase = RegistrarAsistencia(repo)
    asistencia = await usecase(payload.ulid, payload.alumno_dni)
    return {"id": asistencia.id, "ulid": asistencia.ulid, "timestamp": asistencia.timestamp.isoformat()}
