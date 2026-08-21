from typing import List
from sqlalchemy.orm import Session
from app.domain.entities.workshop_group import WorkshopGroup
from app.domain.repositories.workshop_group_repository import WorkshopGroupRepository
from app.infrastructure.models.course_model import WorkshopGroupModel


class WorkshopGroupRepositoryImpl(WorkshopGroupRepository):

    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(model: WorkshopGroupModel) -> WorkshopGroup:
        return WorkshopGroup(
            id=str(model.id),
            course_id=str(model.course_id),
            group_label=model.group_label,
        )

    def get_all(self) -> List[WorkshopGroup]:
        rows = self.db.query(WorkshopGroupModel).order_by(WorkshopGroupModel.group_label).all()
        return [self._to_entity(r) for r in rows]

    def get_by_course(self, course_id: str) -> List[WorkshopGroup]:
        rows = (
            self.db.query(WorkshopGroupModel)
            .filter(WorkshopGroupModel.course_id == course_id)
            .order_by(WorkshopGroupModel.group_label)
            .all()
        )
        return [self._to_entity(r) for r in rows]
