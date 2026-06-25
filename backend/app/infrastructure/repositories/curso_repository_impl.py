from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.curso import Curso
from app.domain.repositories.curso_repository import CursoRepository
from app.infrastructure.models.curso_model import CursoModel

class CursoRepositoryImpl(CursoRepository):

    def __init__(self, db: Session):
        self.db = db

    def _to_entity(self, model: CursoModel) -> Curso:
        return Curso(
            id=str(model.id),
            anio=model.anio,
            division=model.division,
            grupo_taller=model.grupo_taller or '',
            especialidad=model.especialidad or '',
            turno=model.turno.value,
            total_alumnos=0,
            preceptor_id=None,
            horario_ingreso=None,
            horario_egreso=None,
        )

    def get_cursos(self) -> List[Curso]:
        rows = self.db.query(CursoModel).filter(CursoModel.activo == True).all()
        return [self._to_entity(r) for r in rows]

    def get_curso_por_id(self, id: str) -> Optional[Curso]:
        row = self.db.query(CursoModel).filter(CursoModel.id == int(id)).first()
        return self._to_entity(row) if row else None

    def get_cursos_por_turno(self, turno: str) -> List[Curso]:
        rows = self.db.query(CursoModel).filter(
            CursoModel.turno == turno,
            CursoModel.activo == True
        ).all()
        return [self._to_entity(r) for r in rows]