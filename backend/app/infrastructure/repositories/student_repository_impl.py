from typing import List, Optional
from datetime import date
from sqlalchemy.orm import Session
from app.domain.entities.student import Alumno
from app.domain.repositories.student_repository import AlumnoRepository
from app.infrastructure.models.student_model import (
    StudentModel, StudentCourseEnrollmentModel, EnrollmentTypeEnum,
)


class AlumnoRepositoryImpl(AlumnoRepository):
    """Persists the frontend-facing `Alumno` DTO against the new English schema
    (`students` + `student_course_enrollments`). `curso_id` is no longer a
    direct FK on the student: the "current course" is resolved through the
    active enrollment (end_date IS NULL, latest start_date)."""

    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _current_enrollment(student: StudentModel) -> Optional[StudentCourseEnrollmentModel]:
        active = [e for e in student.enrollments if e.end_date is None]
        pool = active or list(student.enrollments)
        if not pool:
            return None
        return max(pool, key=lambda e: e.start_date)

    def _to_entity(self, student: StudentModel) -> Alumno:
        enrollment = self._current_enrollment(student)
        course = enrollment.course if enrollment else None

        course_name = ""
        especialidad = ""
        turno = ""
        curso_id = ""
        recursante = False

        if enrollment:
            curso_id = str(enrollment.course_id)
            recursante = enrollment.enrollment_type == EnrollmentTypeEnum.repeating

        if course:
            course_name = (
                f"{course.academic_year.name} {course.division.name} — "
                f"{course.specialty.name} — {course.shift.name}"
            )
            especialidad = course.specialty.name
            turno = course.shift.name
            if course.workshop_groups:
                workshop_names = ", ".join(wg.name for wg in course.workshop_groups)
                course_name = f"{course_name} ({workshop_names})"

        return Alumno(
            id=str(student.id),
            nombre=student.first_name,
            apellido=student.last_name,
            dni=student.national_id,
            curso_id=curso_id,
            curso=course_name,
            especialidad=especialidad,
            turno=turno,
            recursante=recursante,
            porcentaje_asistencia=0.0,
        )

    def get_alumnos(self) -> List[Alumno]:
        rows = self.db.query(StudentModel).filter(StudentModel.is_active == True).all()
        return [self._to_entity(s) for s in rows]

    def get_alumno_por_id(self, id: str) -> Optional[Alumno]:
        student = self.db.query(StudentModel).filter(StudentModel.id == id).first()
        return self._to_entity(student) if student else None

    def get_alumnos_por_curso(self, curso_id: str) -> List[Alumno]:
        rows = (
            self.db.query(StudentModel)
            .join(StudentCourseEnrollmentModel, StudentCourseEnrollmentModel.student_id == StudentModel.id)
            .filter(
                StudentCourseEnrollmentModel.course_id == curso_id,
                StudentCourseEnrollmentModel.end_date.is_(None),
                StudentModel.is_active == True,
            )
            .all()
        )
        return [self._to_entity(s) for s in rows]

    def crear_alumno(self, alumno: Alumno) -> Alumno:
        student = StudentModel(
            first_name=alumno.nombre,
            last_name=alumno.apellido,
            national_id=alumno.dni,
        )
        self.db.add(student)
        self.db.flush()  # obtain generated student.id before creating the enrollment

        if alumno.curso_id:
            enrollment = StudentCourseEnrollmentModel(
                student_id=student.id,
                course_id=alumno.curso_id,
                enrollment_type=EnrollmentTypeEnum.regular,
                start_date=date.today(),
            )
            self.db.add(enrollment)

        self.db.commit()
        self.db.refresh(student)
        return self._to_entity(student)

    def actualizar_alumno(self, id: str, alumno: Alumno) -> Optional[Alumno]:
        student = self.db.query(StudentModel).filter(StudentModel.id == id).first()
        if not student:
            return None

        student.first_name = alumno.nombre
        student.last_name = alumno.apellido
        student.national_id = alumno.dni

        # Re-point the current enrollment if the course changed. A course change
        # closes the previous enrollment and opens a new one, preserving history.
        if alumno.curso_id:
            current = self._current_enrollment(student)
            if current is None:
                self.db.add(StudentCourseEnrollmentModel(
                    student_id=student.id,
                    course_id=alumno.curso_id,
                    enrollment_type=EnrollmentTypeEnum.regular,
                    start_date=date.today(),
                ))
            elif str(current.course_id) != alumno.curso_id:
                current.end_date = date.today()
                self.db.add(StudentCourseEnrollmentModel(
                    student_id=student.id,
                    course_id=alumno.curso_id,
                    enrollment_type=current.enrollment_type,
                    start_date=date.today(),
                ))

        self.db.commit()
        self.db.refresh(student)
        return self._to_entity(student)
