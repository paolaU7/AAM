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
    división ofrecidos en los desplegables de alta de curso."""

    max_grade_year: int
    max_division: int
