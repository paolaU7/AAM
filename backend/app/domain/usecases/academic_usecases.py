from typing import List, Optional
from app.domain.entities.academic import Subject, SubjectApplicability, Teacher, SubjectTeacherAssignment
from app.domain.repositories.academic_repository import (
    SubjectRepository, SubjectApplicabilityRepository, TeacherRepository, CourseSubjectTeacherRepository,
)
from app.domain.repositories.specialty_repository import SpecialtyRepository
from app.domain.repositories.course_repository import CourseRepository


class AcademicError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


def _extract_db_error_message(exc: Exception) -> str:
    """Mejor esfuerzo para sacar el mensaje real de un error de Postgres
    (p.ej. el RAISE EXCEPTION de un trigger), sin el ruido de CONTEXT que
    agrega el driver."""
    raw = str(getattr(exc, "orig", exc)).strip()
    return raw.split("\n")[0] or "No se pudo completar la operación."


class GetSubjects:
    def __init__(self, repo: SubjectRepository):
        self.repo = repo

    def execute(self, grade_year: Optional[int] = None, specialty_id: Optional[str] = None) -> List[Subject]:
        return self.repo.get_all(grade_year=grade_year, specialty_id=specialty_id)


class CreateSubject:
    def __init__(self, repo: SubjectRepository):
        self.repo = repo

    def execute(self, name: str, subject_type: str) -> Subject:
        name = (name or "").strip()
        if not name:
            raise AcademicError("El nombre de la materia es obligatorio.", 400)
        if subject_type not in ("curricular", "workshop"):
            raise AcademicError("El tipo de materia debe ser 'curricular' o 'workshop'.", 400)
        return self.repo.create(name, subject_type)


class GetSubjectApplicability:
    def __init__(self, repo: SubjectApplicabilityRepository):
        self.repo = repo

    def execute(self, subject_id: str) -> List[SubjectApplicability]:
        return self.repo.get_by_subject(subject_id)


class AddSubjectApplicability:
    """Misma regla que en Cursos (`_CursoForm`): 1ro-3ro => siempre "Ciclo
    Básico" (asignado solo, no elegible a mano), 4to en adelante => nunca
    "Ciclo Básico". Se valida acá, en la app, además del trigger de la DB
    (`enforce_basic_cycle_specialty_subject`), para dar feedback inmediato."""

    def __init__(
        self,
        repo: SubjectApplicabilityRepository,
        subject_repo: SubjectRepository,
        specialty_repo: SpecialtyRepository,
    ):
        self.repo = repo
        self.subject_repo = subject_repo
        self.specialty_repo = specialty_repo

    def execute(self, subject_id: str, grade_year: int, specialty_id: str) -> SubjectApplicability:
        if self.subject_repo.get_by_id(subject_id) is None:
            raise AcademicError("La materia no existe.", 404)
        if grade_year < 1 or grade_year > 7:
            raise AcademicError("El año de cursada debe estar entre 1 y 7.", 400)
        if not specialty_id:
            raise AcademicError("Seleccioná la especialidad.", 400)

        specialty = self.specialty_repo.get_by_id(specialty_id)
        if specialty is None:
            raise AcademicError("La especialidad seleccionada no existe.", 400)
        if grade_year <= 3 and not specialty.is_basic_cycle:
            raise AcademicError('Los años 1ro a 3ro deben habilitarse con la especialidad "Ciclo Básico".', 400)
        if grade_year >= 4 and specialty.is_basic_cycle:
            raise AcademicError('Los años 4to en adelante no pueden habilitarse con "Ciclo Básico".', 400)

        try:
            return self.repo.add(subject_id, grade_year, specialty_id)
        except AcademicError:
            raise
        except Exception as e:
            raise AcademicError(_extract_db_error_message(e), 400)


class RemoveSubjectApplicability:
    def __init__(self, repo: SubjectApplicabilityRepository):
        self.repo = repo

    def execute(self, id: str) -> bool:
        return self.repo.remove(id)


class GetTeachers:
    def __init__(self, repo: TeacherRepository):
        self.repo = repo

    def execute(self) -> List[Teacher]:
        return self.repo.get_all()


class CreateTeacher:
    def __init__(self, repo: TeacherRepository):
        self.repo = repo

    def execute(self, full_name: str, email: Optional[str] = None, phone: Optional[str] = None) -> Teacher:
        full_name = (full_name or "").strip()
        if not full_name:
            raise AcademicError("El nombre del profesor es obligatorio.", 400)
        return self.repo.create(full_name, email=(email or None), phone=(phone or None))


class GetTeacherAssignments:
    """Todas las asignaciones (curso + materia) de UN profesor — para la
    ficha de Profes."""

    def __init__(self, repo: CourseSubjectTeacherRepository):
        self.repo = repo

    def execute(self, teacher_id: str) -> List[SubjectTeacherAssignment]:
        return self.repo.get_by_teacher(teacher_id)


class GetCourseSubjectTeachers:
    def __init__(self, repo: CourseSubjectTeacherRepository):
        self.repo = repo

    def execute(self, course_id: str) -> List[SubjectTeacherAssignment]:
        return self.repo.get_by_course(course_id)


class AssignCourseSubjectTeacher:
    """Espejo, del lado de la app, del trigger `enforce_course_subject_
    applicability`: la materia tiene que estar habilitada (subject_
    applicability) para el año+especialidad de ESE curso. Igual que en
    Cursos con las especialidades, no confiamos solo en el trigger."""

    def __init__(
        self,
        repo: CourseSubjectTeacherRepository,
        course_repo: CourseRepository,
        subject_repo: SubjectRepository,
    ):
        self.repo = repo
        self.course_repo = course_repo
        self.subject_repo = subject_repo

    def execute(self, course_id: str, subject_id: str, teacher_id: str) -> SubjectTeacherAssignment:
        if not subject_id or not teacher_id:
            raise AcademicError("Materia y profesor son obligatorios.", 400)

        curso = self.course_repo.get_course_by_id(course_id)
        if curso is None:
            raise AcademicError("El curso no existe.", 404)

        materias_habilitadas = self.subject_repo.get_all(
            grade_year=curso.grade_year, specialty_id=curso.specialty_id,
        )
        if subject_id not in {s.id for s in materias_habilitadas}:
            raise AcademicError(
                "Esa materia no está habilitada para el año/especialidad de este curso. "
                "Configurá su aplicabilidad desde la sección Materias.",
                400,
            )

        try:
            return self.repo.assign(course_id, subject_id, teacher_id)
        except AcademicError:
            raise
        except Exception as e:
            raise AcademicError(_extract_db_error_message(e), 400)


class RemoveCourseSubjectTeacher:
    def __init__(self, repo: CourseSubjectTeacherRepository):
        self.repo = repo

    def execute(self, course_id: str, subject_id: str) -> bool:
        return self.repo.remove(course_id, subject_id)
