from typing import List, Optional
from app.domain.entities.student import Alumno
from app.domain.repositories.student_repository import AlumnoRepository
from app.domain.repositories.course_repository import CourseRepository
from app.domain.repositories.workshop_group_repository import WorkshopGroupRepository


class AltaAlumnoError(Exception):
    """Business error during the manual student registration flow. Carries the
    HTTP status the API layer should map it to."""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code

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


class ActualizarAlumno:
    def __init__(self, repo: AlumnoRepository):
        self.repo = repo

    def execute(self, id: str, alumno: Alumno) -> Optional[Alumno]:
        return self.repo.actualizar_alumno(id, alumno)


class CrearAlumnoManual:
    """Manual student registration: the course is already resolved by the
    frontend (from the 3-step cascade against `/courses`) and sent as
    `course_id` directly. Validates the course exists, the DNI is unique,
    and — if given — that the workshop group belongs to that same course
    (groups are a subdivision of one specific course, not shared)."""

    def __init__(
        self,
        alumno_repo: AlumnoRepository,
        course_repo: CourseRepository,
        workshop_group_repo: WorkshopGroupRepository,
    ):
        self.alumno_repo = alumno_repo
        self.course_repo = course_repo
        self.workshop_group_repo = workshop_group_repo

    def execute(
        self,
        *,
        first_name: str,
        last_name: str,
        national_id: str,
        course_id: str,
        workshop_group_id: Optional[str] = None,
    ) -> Alumno:
        first_name = (first_name or "").strip()
        last_name = (last_name or "").strip()
        national_id = (national_id or "").strip()

        if not first_name or not last_name or not national_id:
            raise AltaAlumnoError("Nombre, apellido y DNI son obligatorios.", 400)

        if not course_id or self.course_repo.get_course_by_id(course_id) is None:
            raise AltaAlumnoError("El curso seleccionado no existe.", 400)

        if workshop_group_id:
            grupos_del_curso = {g.id for g in self.workshop_group_repo.get_by_course(course_id)}
            if workshop_group_id not in grupos_del_curso:
                raise AltaAlumnoError("El grupo de taller no pertenece al curso seleccionado.", 400)

        if self.alumno_repo.existe_dni(national_id):
            raise AltaAlumnoError("Ya existe un alumno registrado con ese DNI.", 409)

        try:
            return self.alumno_repo.crear_alumno_manual(
                first_name=first_name,
                last_name=last_name,
                national_id=national_id,
                course_id=course_id,
                workshop_group_id=workshop_group_id,
            )
        except ValueError as e:
            raise AltaAlumnoError(str(e), 400)
