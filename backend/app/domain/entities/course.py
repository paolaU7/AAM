from dataclasses import dataclass
from typing import Optional


@dataclass
class Course:
    """Domain entity: a course is the combination of three independent
    numeric dimensions (academic_year, grade_year, division). `specialty` is
    a nullable course-level attribute. `name`/`total_students` are display
    helpers computed by the repository, not stored columns."""

    id: str
    academic_year: int
    grade_year: int
    division: int
    specialty: Optional[str] = None
    total_students: int = 0
    name: str = ""
