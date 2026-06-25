
from typing import List, Optional
from app.domain.entities.curso import Curso
from app.domain.repositories.curso_repository import CursoRepository

class GetCursos:
    def __init__(self, repo: CursoRepository):
        self.repo = repo

    def execute(self) -> List[Curso]:
        return self.repo.get_cursos()


class GetCursoPorId:
    def __init__(self, repo: CursoRepository):
        self.repo = repo

    def execute(self, id: str) -> Optional[Curso]:
        return self.repo.get_curso_por_id(id)


class GetCursosPorTurno:
    def __init__(self, repo: CursoRepository):
        self.repo = repo

    def execute(self, turno: str) -> List[Curso]:
        return self.repo.get_cursos_por_turno(turno)