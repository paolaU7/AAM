from datetime import datetime
from typing import Optional, List
from app.domain.entities.asistencia import Asistencia
from app.domain.repositories.asistencia_repository import AsistenciaRepository
from app.infrastructure.models import AsistenciaModel
from app.infrastructure.database import SessionLocal


class AsistenciaRepositoryImpl(AsistenciaRepository):
    async def add(self, asistencia: Asistencia) -> Asistencia:
        with SessionLocal() as session:
            model = AsistenciaModel(ulid=asistencia.ulid, alumno_dni=asistencia.alumno_dni, timestamp=asistencia.timestamp)
            session.add(model)
            session.commit()
            session.refresh(model)
            return Asistencia(id=model.id, ulid=model.ulid, alumno_dni=model.alumno_dni, timestamp=model.timestamp)

    async def get_by_ulid(self, ulid: str) -> Optional[Asistencia]:
        with SessionLocal() as session:
            model = session.query(AsistenciaModel).filter_by(ulid=ulid).first()
            if not model:
                return None
            return Asistencia(id=model.id, ulid=model.ulid, alumno_dni=model.alumno_dni, timestamp=model.timestamp)

    async def list_all(self) -> List[Asistencia]:
        with SessionLocal() as session:
            rows = session.query(AsistenciaModel).order_by(AsistenciaModel.timestamp.desc()).all()
            return [Asistencia(id=r.id, ulid=r.ulid, alumno_dni=r.alumno_dni, timestamp=r.timestamp) for r in rows]
