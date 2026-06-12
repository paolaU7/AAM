from typing import List, Optional
from app.domain.entities.alumno import Alumno
from app.domain.repositories.alumno_repository import AlumnoRepository
from app.infrastructure.models import AlumnoModel
from app.infrastructure.database import SessionLocal


class AlumnoRepositoryImpl(AlumnoRepository):
    async def list_all(self) -> List[Alumno]:
        with SessionLocal() as session:
            rows = session.query(AlumnoModel).order_by(AlumnoModel.apellido).all()
            return [Alumno(id=r.id, nombre=r.nombre, apellido=r.apellido, dni=r.dni, curso=r.curso, especialidad=r.especialidad, recursante=r.recursante) for r in rows]

    async def get_by_dni(self, dni: str) -> Optional[Alumno]:
        with SessionLocal() as session:
            r = session.query(AlumnoModel).filter_by(dni=dni).first()
            if not r:
                return None
            return Alumno(id=r.id, nombre=r.nombre, apellido=r.apellido, dni=r.dni, curso=r.curso, especialidad=r.especialidad, recursante=r.recursante)

    async def add(self, alumno: Alumno) -> Alumno:
        with SessionLocal() as session:
            model = AlumnoModel(nombre=alumno.nombre, apellido=alumno.apellido, dni=alumno.dni, curso=alumno.curso, especialidad=alumno.especialidad, recursante=alumno.recursante)
            session.add(model)
            session.commit()
            session.refresh(model)
            return Alumno(id=model.id, nombre=model.nombre, apellido=model.apellido, dni=model.dni, curso=model.curso, especialidad=model.especialidad, recursante=model.recursante)
