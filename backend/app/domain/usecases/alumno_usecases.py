from typing import List, Optional
from app.domain.entities.alumno import Alumno
from app.domain.repositories.alumno_repository import AlumnoRepository

class GetAlumnos:
    def __init__(self, repo: AlumnoRepository):
        self.repo = repo

    def execute(self) -> List[Alumno]:
        return self.repo.get_alumnos()


class GetAlumnoPorId:
    def __init__(self, repo: AlumnoRepository):
        self.repo = repo

    def execute(self, id: str) -> Optional[Alumno]:
        return self.repo.get_alumno_por_id(id)


class CrearAlumno:
    def __init__(self, repo: AlumnoRepository):
        self.repo = repo

    def execute(self, alumno: Alumno) -> Alumno:
        return self.repo.crear_alumno(alumno)


class ActualizarAlumno:
    def __init__(self, repo: AlumnoRepository):
        self.repo = repo

    def execute(self, id: str, alumno: Alumno) -> Optional[Alumno]:
        return self.repo.actualizar_alumno(id, alumno)