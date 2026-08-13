from dataclasses import dataclass, field
from typing import List, Optional
from app.domain.repositories.student_repository import AlumnoRepository
from app.domain.repositories.course_repository import CourseRepository
from app.domain.repositories.workshop_group_repository import WorkshopGroupRepository


@dataclass
class ImportRowResult:
    fila: int
    alumno_id: Optional[str] = None
    motivo: Optional[str] = None


@dataclass
class ImportReport:
    curso_id: str
    total_filas: int
    creados: List[ImportRowResult] = field(default_factory=list)
    errores: List[ImportRowResult] = field(default_factory=list)


class ImportarAlumnosExcelError(Exception):
    """Error que frena la importación COMPLETA (encabezado inválido, curso
    inexistente). Los errores por FILA no usan esta excepción: se acumulan en
    el reporte y no abortan el resto del archivo."""

    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class ImportarAlumnosExcel:
    """Importa los alumnos de UN curso (año lectivo + año de cursada +
    división, fijos en el encabezado del Excel). Cada fila se procesa de
    forma independiente: un error en una fila no aborta las demás."""

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
        academic_year: int,
        grade_year: int,
        division: int,
        rows: List[dict],  # cada dict: {fila, dni, nombre, apellido, grupo_taller}
    ) -> ImportReport:
        course = self.course_repo.resolve_course(academic_year, grade_year, division)
        if course is None:
            raise ImportarAlumnosExcelError(
                f"No existe un curso cargado para año lectivo {academic_year}, "
                f"año de cursada {grade_year}, división {division}.",
                400,
            )

        # Catálogo de grupos de taller válidos para ESTE curso puntual — los
        # grupos son una subdivisión interna del curso, no se comparten.
        workshop_groups = self.workshop_group_repo.get_by_course(course.id)
        workshop_by_name = {w.group_label.strip().upper(): w.id for w in workshop_groups}

        report = ImportReport(curso_id=course.id, total_filas=len(rows))

        for row in rows:
            fila = row.get("fila")
            dni = str(row.get("dni") or "").strip()
            nombre = str(row.get("nombre") or "").strip()
            apellido = str(row.get("apellido") or "").strip()
            grupo_taller_raw = str(row.get("grupo_taller") or "").strip()

            # Fila vacía del template (placeholder hasta la #60): se ignora, no
            # cuenta ni como creada ni como error.
            if not dni and not nombre and not apellido and not grupo_taller_raw:
                report.total_filas -= 1
                continue

            try:
                if not dni or not nombre or not apellido:
                    raise ValueError("Faltan datos obligatorios (DNI, nombre o apellido).")

                workshop_group_id = None
                if grupo_taller_raw:
                    key = grupo_taller_raw.upper()
                    if key not in workshop_by_name:
                        disponibles = ", ".join(sorted(workshop_by_name)) or "ninguno"
                        raise ValueError(
                            f"El grupo de taller '{grupo_taller_raw}' no existe para "
                            f"este curso. Disponibles: {disponibles}."
                        )
                    workshop_group_id = workshop_by_name[key]

                if self.alumno_repo.existe_dni(dni):
                    raise ValueError("Ya existe un alumno registrado con ese DNI.")

                alumno = self.alumno_repo.crear_alumno_manual(
                    first_name=nombre,
                    last_name=apellido,
                    national_id=dni,
                    course_id=course.id,
                    workshop_group_id=workshop_group_id,
                )

                report.creados.append(ImportRowResult(fila=fila, alumno_id=alumno.id))
            except Exception as e:
                report.errores.append(ImportRowResult(fila=fila, motivo=str(e)))

        return report
