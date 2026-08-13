from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.academic import Subject, Teacher, SubjectTeacherAssignment
from app.domain.repositories.academic_repository import (
    SubjectRepository, TeacherRepository, CourseSubjectTeacherRepository,
)
from app.infrastructure.models.academic_model import SubjectModel, TeacherModel, CourseSubjectTeacherModel


class SubjectRepositoryImpl(SubjectRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: SubjectModel) -> Subject:
        return Subject(id=str(m.id), name=m.name)

    def get_all(self) -> List[Subject]:
        rows = self.db.query(SubjectModel).order_by(SubjectModel.name).all()
        return [self._to_entity(r) for r in rows]

    def create(self, name: str) -> Subject:
        model = SubjectModel(name=name)
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)


class TeacherRepositoryImpl(TeacherRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: TeacherModel) -> Teacher:
        return Teacher(id=str(m.id), full_name=m.full_name, email=m.email, phone=m.phone)

    def get_all(self) -> List[Teacher]:
        rows = self.db.query(TeacherModel).order_by(TeacherModel.full_name).all()
        return [self._to_entity(r) for r in rows]

    def create(self, full_name: str, email: Optional[str] = None, phone: Optional[str] = None) -> Teacher:
        model = TeacherModel(full_name=full_name, email=email, phone=phone)
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)


class CourseSubjectTeacherRepositoryImpl(CourseSubjectTeacherRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: CourseSubjectTeacherModel) -> SubjectTeacherAssignment:
        return SubjectTeacherAssignment(
            course_id=str(m.course_id),
            subject_id=str(m.subject_id),
            subject_name=m.subject.name,
            teacher_id=str(m.teacher_id),
            teacher_name=m.teacher.full_name,
            teacher_email=m.teacher.email,
            teacher_phone=m.teacher.phone,
        )

    def get_by_course(self, course_id: str) -> List[SubjectTeacherAssignment]:
        rows = (
            self.db.query(CourseSubjectTeacherModel)
            .filter(CourseSubjectTeacherModel.course_id == course_id)
            .all()
        )
        return [self._to_entity(r) for r in rows]

    def assign(self, course_id: str, subject_id: str, teacher_id: str) -> SubjectTeacherAssignment:
        existing = (
            self.db.query(CourseSubjectTeacherModel)
            .filter(
                CourseSubjectTeacherModel.course_id == course_id,
                CourseSubjectTeacherModel.subject_id == subject_id,
            )
            .first()
        )
        if existing is not None:
            existing.teacher_id = teacher_id
            self.db.commit()
            self.db.refresh(existing)
            return self._to_entity(existing)

        model = CourseSubjectTeacherModel(course_id=course_id, subject_id=subject_id, teacher_id=teacher_id)
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)

    def remove(self, course_id: str, subject_id: str) -> bool:
        existing = (
            self.db.query(CourseSubjectTeacherModel)
            .filter(
                CourseSubjectTeacherModel.course_id == course_id,
                CourseSubjectTeacherModel.subject_id == subject_id,
            )
            .first()
        )
        if existing is None:
            return False
        self.db.delete(existing)
        self.db.commit()
        return True
