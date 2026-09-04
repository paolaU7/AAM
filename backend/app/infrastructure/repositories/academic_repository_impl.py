from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.academic import Subject, SubjectApplicability, Teacher, SubjectTeacherAssignment
from app.domain.repositories.academic_repository import (
    SubjectRepository, SubjectApplicabilityRepository, TeacherRepository, CourseSubjectTeacherRepository,
)
from app.infrastructure.models.academic_model import (
    SubjectModel, SubjectApplicabilityModel, SubjectTypeEnum, TeacherModel, CourseSubjectTeacherModel,
)
from app.infrastructure.models.course_model import CourseModel
from app.infrastructure.repositories.course_repository_impl import _grade_year_ordinal, _division_ordinal


class SubjectRepositoryImpl(SubjectRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: SubjectModel) -> Subject:
        return Subject(id=str(m.id), name=m.name, subject_type=m.subject_type.value)

    def get_all(self, grade_year: Optional[int] = None, specialty_id: Optional[str] = None) -> List[Subject]:
        query = self.db.query(SubjectModel)
        if grade_year is not None and specialty_id is not None:
            query = (
                query.join(SubjectApplicabilityModel, SubjectApplicabilityModel.subject_id == SubjectModel.id)
                .filter(
                    SubjectApplicabilityModel.grade_year == grade_year,
                    SubjectApplicabilityModel.specialty_id == specialty_id,
                )
                .distinct()
            )
        rows = query.order_by(SubjectModel.name).all()
        return [self._to_entity(r) for r in rows]

    def get_by_id(self, id: str) -> Optional[Subject]:
        model = self.db.query(SubjectModel).filter(SubjectModel.id == id).first()
        return self._to_entity(model) if model else None

    def create(self, name: str, subject_type: str) -> Subject:
        model = SubjectModel(name=name, subject_type=SubjectTypeEnum(subject_type))
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)


class SubjectApplicabilityRepositoryImpl(SubjectApplicabilityRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: SubjectApplicabilityModel) -> SubjectApplicability:
        return SubjectApplicability(
            id=str(m.id),
            subject_id=str(m.subject_id),
            grade_year=m.grade_year,
            specialty_id=str(m.specialty_id),
            specialty_name=m.specialty.name,
        )

    def get_by_subject(self, subject_id: str) -> List[SubjectApplicability]:
        rows = (
            self.db.query(SubjectApplicabilityModel)
            .filter(SubjectApplicabilityModel.subject_id == subject_id)
            .order_by(SubjectApplicabilityModel.grade_year)
            .all()
        )
        return [self._to_entity(r) for r in rows]

    def add(self, subject_id: str, grade_year: int, specialty_id: str) -> SubjectApplicability:
        model = SubjectApplicabilityModel(subject_id=subject_id, grade_year=grade_year, specialty_id=specialty_id)
        self.db.add(model)
        try:
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
        self.db.refresh(model)
        return self._to_entity(model)

    def remove(self, id: str) -> bool:
        model = self.db.query(SubjectApplicabilityModel).filter(SubjectApplicabilityModel.id == id).first()
        if model is None:
            return False
        self.db.delete(model)
        self.db.commit()
        return True


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
        course = m.course
        course_name = None
        if course is not None:
            course_name = (
                f"{_grade_year_ordinal(course.grade_year)} "
                f"{_division_ordinal(course.division)} ({course.academic_year})"
            )
        return SubjectTeacherAssignment(
            course_id=str(m.course_id),
            subject_id=str(m.subject_id),
            subject_name=m.subject.name,
            subject_type=m.subject.subject_type.value,
            teacher_id=str(m.teacher_id),
            teacher_name=m.teacher.full_name,
            teacher_email=m.teacher.email,
            teacher_phone=m.teacher.phone,
            course_name=course_name,
        )

    def get_by_course(self, course_id: str) -> List[SubjectTeacherAssignment]:
        rows = (
            self.db.query(CourseSubjectTeacherModel)
            .filter(CourseSubjectTeacherModel.course_id == course_id)
            .all()
        )
        return [self._to_entity(r) for r in rows]

    def get_by_teacher(self, teacher_id: str) -> List[SubjectTeacherAssignment]:
        rows = (
            self.db.query(CourseSubjectTeacherModel)
            .filter(CourseSubjectTeacherModel.teacher_id == teacher_id)
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
            try:
                self.db.commit()
            except Exception:
                self.db.rollback()
                raise
            self.db.refresh(existing)
            return self._to_entity(existing)

        model = CourseSubjectTeacherModel(course_id=course_id, subject_id=subject_id, teacher_id=teacher_id)
        self.db.add(model)
        try:
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
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
