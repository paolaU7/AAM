from dataclasses import dataclass, field
from typing import List


@dataclass
class Course:
    """Domain entity: a course is the combination of the four independent
    dimensions (academic year + division + specialty + shift). Workshop groups
    are a separate N:M relation. `name`/`horario` are display helpers built by
    the repository."""

    id: str
    academic_year: str          # academic year name, e.g. "4th Year"
    division: str               # "A", "B", "C"...
    specialty: str
    shift: str                  # "Morning" | "Afternoon" | "Evening"
    total_students: int
    name: str = ""
    horario: str = ""
    workshop_groups: List[str] = field(default_factory=list)
