from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.alumno import Alumno
from app.domain.repositories.alumno_repository import AlumnoRepository
from app.infrastructure.models.alumno_model import AlumnoModel
from app.infrastructure.models.curso_model import CursoModel


class AlumnoRepositoryImpl(AlumnoRepository):

    def __init__(self, db: Session):
        self.db = db

    def _to_entity(self, model: AlumnoModel, curso: CursoModel) -> Alumno:
        return Alumno(
            id=str(model.id),
            nombre=model.nombre,
            apellido=model.apellido,
            dni=model.dni,
            curso_id=str(model.curso_id),
            curso=f"{curso.anio}° {curso.division}° {curso.grupo_taller} — {curso.especialidad or ''}" if curso else "",
            especialidad=curso.especialidad or '' if curso else "",
            turno=curso.turno.value if curso else "",
            recursante=False,
            porcentaje_asistencia=0.0,
        )

    def get_alumnos(self) -> List[Alumno]:
        rows = self.db.query(AlumnoModel, CursoModel).join(
            CursoModel, AlumnoModel.curso_id == CursoModel.id
        ).filter(AlumnoModel.activo == True).all()

        return [self._to_entity(a, c) for a, c in rows]

    def get_alumno_por_id(self, id: str) -> Optional[Alumno]:
        row = self.db.query(AlumnoModel, CursoModel).join(
            CursoModel, AlumnoModel.curso_id == CursoModel.id
        ).filter(AlumnoModel.id == int(id)).first()

        return self._to_entity(row[0], row[1]) if row else None

    def get_alumnos_por_curso(self, curso_id: str) -> List[Alumno]:
        rows = self.db.query(AlumnoModel, CursoModel).join(
            CursoModel, AlumnoModel.curso_id == CursoModel.id
        ).filter(
            AlumnoModel.curso_id == int(curso_id),
            AlumnoModel.activo == True
        ).all()

        return [self._to_entity(a, c) for a, c in rows]

    def crear_alumno(self, alumno: Alumno) -> Alumno:
        model = AlumnoModel(
            nombre=alumno.nombre,
            apellido=alumno.apellido,
            dni=alumno.dni,
            curso_id=int(alumno.curso_id),
        )

        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)

        curso = self.db.query(CursoModel).filter(
            CursoModel.id == model.curso_id
        ).first()

        return self._to_entity(model, curso)

    def actualizar_alumno(self, id: str, alumno: Alumno) -> Optional[Alumno]:
        model = self.db.query(AlumnoModel).filter(
            AlumnoModel.id == int(id)
        ).first()

        if not model:
            return None

        model.nombre = alumno.nombre
        model.apellido = alumno.apellido
        model.dni = alumno.dni
        model.curso_id = int(alumno.curso_id)

        self.db.commit()
        self.db.refresh(model)

        curso = self.db.query(CursoModel).filter(
            CursoModel.id == model.curso_id
        ).first()

        return self._to_entity(model, curso)