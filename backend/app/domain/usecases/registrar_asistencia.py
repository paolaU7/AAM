from datetime import datetime
from app.domain.entities.asistencia import Asistencia
from app.domain.repositories.asistencia_repository import AsistenciaRepository


class RegistrarAsistencia:
    def __init__(self, repo: AsistenciaRepository):
        self._repo = repo

    async def __call__(self, ulid: str, alumno_dni: str | None = None) -> Asistencia:
        # deduplication: if ulid exists, return existing
        existing = await self._repo.get_by_ulid(ulid)
        if existing:
            return existing

        asistencia = Asistencia(id=None, ulid=ulid, alumno_dni=alumno_dni, timestamp=datetime.utcnow())
        return await self._repo.add(asistencia)
