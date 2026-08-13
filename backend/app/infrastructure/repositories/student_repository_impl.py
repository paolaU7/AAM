from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.student import Alumno
from app.domain.repositories.student_repository import AlumnoRepository
from app.infrastructure.models.student_model import StudentModel
from app.infrastructure.repositories.course_repository_impl import (
    _grade_year_ordinal, _division_ordinal,
)


class AlumnoRepositoryImpl(AlumnoRepository):
    """Persists the frontend-facing `Alumno` DTO against `students`, which now
    has a direct `course_id` FK (no enrollment-history table)."""

    def __init__(self, db: Session):
        self.db = db

    def _to_entity(self, student: StudentModel) -> Alumno:
        course = student.course
        curso_label = ""
        if course is not None:
            curso_label = (
                f"{_grade_year_ordinal(course.grade_year)} "
                f"{_division_ordinal(course.division)} ({course.academic_year})"
            )

        return Alumno(
            id=str(student.id),
            nombre=student.first_name,
            apellido=student.last_name,
            dni=student.document_number or "",
            curso_id=str(student.course_id),
            curso=curso_label,
            recursante=student.is_repeating_student,
            porcentaje_asistencia=0.0,
            workshop_group_id=str(student.workshop_group_id) if student.workshop_group_id else None,
            taller=student.workshop_group.group_label if student.workshop_group else None,
        )

    def get_alumnos(self) -> List[Alumno]:
        rows = self.db.query(StudentModel).all()
        return [self._to_entity(s) for s in rows]

    def get_alumno_por_id(self, id: str) -> Optional[Alumno]:
        student = self.db.query(StudentModel).filter(StudentModel.id == id).first()
        return self._to_entity(student) if student else None

    def get_alumnos_por_curso(self, curso_id: str) -> List[Alumno]:
        rows = self.db.query(StudentModel).filter(StudentModel.course_id == curso_id).all()
        return [self._to_entity(s) for s in rows]

    def existe_dni(self, dni: str) -> bool:
        return (
            self.db.query(StudentModel)
            .filter(StudentModel.document_number == dni)
            .first()
            is not None
        )

    def crear_alumno_manual(
        self,
        first_name: str,
        last_name: str,
        national_id: str,
        course_id: str,
        workshop_group_id: Optional[str] = None,
    ) -> Alumno:
        student = StudentModel(
            first_name=first_name,
            last_name=last_name,
            document_number=national_id,
            course_id=course_id,
            workshop_group_id=workshop_group_id,
        )
        self.db.add(student)
        self.db.commit()
        self.db.refresh(student)
        return self._to_entity(student)

    def actualizar_alumno(self, id: str, alumno: Alumno) -> Optional[Alumno]:
        student = self.db.query(StudentModel).filter(StudentModel.id == id).first()
        if not student:
            return None

        student.first_name = alumno.nombre
        student.last_name = alumno.apellido
        student.document_number = alumno.dni
        if alumno.curso_id:
            student.course_id = alumno.curso_id
        student.workshop_group_id = alumno.workshop_group_id

        self.db.commit()
        self.db.refresh(student)
        return self._to_entity(student)
