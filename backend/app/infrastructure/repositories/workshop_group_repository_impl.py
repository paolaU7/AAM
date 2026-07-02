from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.workshop_group import WorkshopGroup
from app.domain.repositories.workshop_group_repository import WorkshopGroupRepository
from app.infrastructure.models.course_model import WorkshopGroupModel
from app.infrastructure.models.student_model import StudentModel


class WorkshopGroupRepositoryImpl(WorkshopGroupRepository):

    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(model: WorkshopGroupModel) -> WorkshopGroup:
        return WorkshopGroup(id=model.id, name=model.name)

    def get_all(self) -> List[WorkshopGroup]:
        rows = self.db.query(WorkshopGroupModel).order_by(WorkshopGroupModel.name).all()
        return [self._to_entity(r) for r in rows]

    def _get_student(self, student_id: str) -> Optional[StudentModel]:
        return self.db.query(StudentModel).filter(StudentModel.id == student_id).first()

    def get_for_student(self, student_id: str) -> Optional[List[WorkshopGroup]]:
        student = self._get_student(student_id)
        if student is None:
            return None
        groups = sorted(student.workshop_groups, key=lambda wg: wg.name)
        return [self._to_entity(wg) for wg in groups]

    def add_to_student(self, student_id: str, workshop_group_id: int) -> bool:
        student = self._get_student(student_id)
        if student is None:
            return False
        wg = self.db.query(WorkshopGroupModel).filter(
            WorkshopGroupModel.id == workshop_group_id
        ).first()
        if wg is None:
            return False
        if wg not in student.workshop_groups:
            student.workshop_groups.append(wg)
            self.db.commit()
        return True

    def remove_from_student(self, student_id: str, workshop_group_id: int) -> bool:
        student = self._get_student(student_id)
        if student is None:
            return False
        wg = next((w for w in student.workshop_groups if w.id == workshop_group_id), None)
        if wg is not None:
            student.workshop_groups.remove(wg)
            self.db.commit()
        return True
