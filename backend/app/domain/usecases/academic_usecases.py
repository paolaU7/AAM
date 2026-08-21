from typing import List, Optional
from app.domain.entities.academic import Subject, Teacher, SubjectTeacherAssignment
from app.domain.repositories.academic_repository import (
    SubjectRepository, TeacherRepository, CourseSubjectTeacherRepository,
)


class AcademicError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class GetSubjects:
    def __init__(self, repo: SubjectRepository):
        self.repo = repo

    def execute(self) -> List[Subject]:
        return self.repo.get_all()


class CreateSubject:
    def __init__(self, repo: SubjectRepository):
        self.repo = repo

    def execute(self, name: str) -> Subject:
        name = (name or "").strip()
        if not name:
            raise AcademicError("El nombre de la materia es obligatorio.", 400)
        return self.repo.create(name)


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


class GetCourseSubjectTeachers:
    def __init__(self, repo: CourseSubjectTeacherRepository):
        self.repo = repo

    def execute(self, course_id: str) -> List[SubjectTeacherAssignment]:
        return self.repo.get_by_course(course_id)


class AssignCourseSubjectTeacher:
    def __init__(self, repo: CourseSubjectTeacherRepository):
        self.repo = repo

    def execute(self, course_id: str, subject_id: str, teacher_id: str) -> SubjectTeacherAssignment:
        if not subject_id or not teacher_id:
            raise AcademicError("Materia y profesor son obligatorios.", 400)
        return self.repo.assign(course_id, subject_id, teacher_id)


class RemoveCourseSubjectTeacher:
    def __init__(self, repo: CourseSubjectTeacherRepository):
        self.repo = repo

    def execute(self, course_id: str, subject_id: str) -> bool:
        return self.repo.remove(course_id, subject_id)
