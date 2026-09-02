from dataclasses import dataclass


@dataclass
class Course:
    """Domain entity: a course is the combination of three independent
    numeric dimensions (academic_year, grade_year, division). `specialty_id`
    is SIEMPRE obligatorio (1ro-3ro -> "Ciclo Básico" asignado solo por la
    UI). `specialty_name`/`name`/`total_students` son helpers de display
    calculados por el repositorio, no columnas propias."""

    id: str
    academic_year: int
    grade_year: int
    division: int
    specialty_id: str
    specialty_name: str
    total_students: int = 0
    name: str = ""
