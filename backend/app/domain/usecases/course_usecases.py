from typing import List, Optional
from app.domain.entities.course import Course
from app.domain.repositories.course_repository import CourseRepository
from app.domain.repositories.specialty_repository import SpecialtyRepository


class CourseError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


def _extract_db_error_message(exc: Exception) -> str:
    """Mejor esfuerzo para sacar el mensaje real de un error de Postgres
    (p.ej. el RAISE EXCEPTION del trigger enforce_basic_cycle_specialty),
    sin el ruido de CONTEXT/traceback que agrega el driver."""
    raw = str(getattr(exc, "orig", exc)).strip()
    return raw.split("\n")[0] or "No se pudo guardar el curso."


class GetCourses:
    def __init__(self, repo: CourseRepository):
        self.repo = repo

    def execute(self) -> List[Course]:
        return self.repo.get_courses()


class GetCourseById:
    def __init__(self, repo: CourseRepository):
        self.repo = repo

    def execute(self, id: str) -> Optional[Course]:
        return self.repo.get_course_by_id(id)


def _validate_dimensions(grade_year: int, division: int) -> None:
    if grade_year < 1 or grade_year > 7:
        raise CourseError("El año de cursada debe estar entre 1 y 7.", 400)
    if division < 1:
        raise CourseError("La división debe ser mayor a 0.", 400)


def _validate_specialty(
    specialty_repo: SpecialtyRepository, grade_year: int, specialty_id: str,
) -> None:
    """Espejo, del lado de la app, de la regla que también fuerza el
    trigger `enforce_basic_cycle_specialty` en la DB: 1ro-3ro siempre
    "Ciclo Básico", 4to en adelante nunca. Da feedback inmediato en vez de
    depender solo de que el trigger la rechace."""
    if not specialty_id:
        raise CourseError("Seleccioná la especialidad.", 400)
    specialty = specialty_repo.get_by_id(specialty_id)
    if specialty is None:
        raise CourseError("La especialidad seleccionada no existe.", 400)
    if grade_year <= 3 and not specialty.is_basic_cycle:
        raise CourseError('Los cursos de 1ro a 3ro deben tener la especialidad "Ciclo Básico".', 400)
    if grade_year >= 4 and specialty.is_basic_cycle:
        raise CourseError('Los cursos de 4to en adelante no pueden tener la especialidad "Ciclo Básico".', 400)


class CreateCourse:
    def __init__(self, repo: CourseRepository, specialty_repo: SpecialtyRepository):
        self.repo = repo
        self.specialty_repo = specialty_repo

    def execute(
        self, *, academic_year: int, grade_year: int, division: int, specialty_id: str,
    ) -> Course:
        _validate_dimensions(grade_year, division)
        _validate_specialty(self.specialty_repo, grade_year, specialty_id)
        if self.repo.resolve_course(academic_year, grade_year, division) is not None:
            raise CourseError("Ya existe un curso con ese año lectivo, año de cursada y división.", 409)

        try:
            return self.repo.create_course(
                academic_year=academic_year, grade_year=grade_year, division=division,
                specialty_id=specialty_id,
            )
        except CourseError:
            raise
        except Exception as e:
            # Red de seguridad: si por algún bug igual se manda una
            # combinación inválida, mostramos el mensaje real del trigger
            # tal cual, no uno genérico.
            raise CourseError(_extract_db_error_message(e), 400)


class UpdateCourse:
    def __init__(self, repo: CourseRepository, specialty_repo: SpecialtyRepository):
        self.repo = repo
        self.specialty_repo = specialty_repo

    def execute(
        self, *, id: str, academic_year: int, grade_year: int, division: int, specialty_id: str,
    ) -> Course:
        _validate_dimensions(grade_year, division)
        _validate_specialty(self.specialty_repo, grade_year, specialty_id)
        existing = self.repo.resolve_course(academic_year, grade_year, division)
        if existing is not None and existing.id != id:
            raise CourseError("Ya existe un curso con ese año lectivo, año de cursada y división.", 409)

        try:
            updated = self.repo.update_course(
                id=id, academic_year=academic_year, grade_year=grade_year, division=division,
                specialty_id=specialty_id,
            )
        except CourseError:
            raise
        except Exception as e:
            raise CourseError(_extract_db_error_message(e), 400)

        if updated is None:
            raise CourseError("El curso no existe.", 404)
        return updated
