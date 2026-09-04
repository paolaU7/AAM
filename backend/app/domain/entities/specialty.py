from dataclasses import dataclass


@dataclass(frozen=True)
class Specialty:
    """Catálogo de especialidades. "Ciclo Básico" es la única con
    is_basic_cycle=True — nunca la elige el usuario a mano, se asigna sola
    a cursos de 1ro a 3ro."""

    id: str
    name: str
    is_basic_cycle: bool


@dataclass(frozen=True)
class SchoolSettings:
    """Fila única de configuración general: techo de año de cursada y de
    división ofrecidos en los desplegables de alta de curso, más los
    umbrales que usa el panel de notificaciones (campana del header)."""

    max_grade_year: int
    max_division: int
    consecutive_absences_alert_threshold: int = 3
    preceptor_temp_assignment_alert_days: int = 2
    schedule_exception_alert_days: int = 2
