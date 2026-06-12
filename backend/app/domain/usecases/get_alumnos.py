from typing import List
from app.domain.repositories.alumno_repository import AlumnoRepository
from app.domain.entities.alumno import Alumno


class GetAlumnos:
    def __init__(self, repo: AlumnoRepository):
        self._repo = repo

    async def __call__(self) -> List[Alumno]:
        return await self._repo.list_all()
