from typing import List, Optional
from sqlalchemy.orm import Session
from app.domain.entities.specialty import Specialty, SchoolSettings
from app.domain.repositories.specialty_repository import SpecialtyRepository, SchoolSettingsRepository
from app.infrastructure.models.settings_model import SpecialtyModel, SchoolSettingsModel


class SpecialtyRepositoryImpl(SpecialtyRepository):
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(m: SpecialtyModel) -> Specialty:
        return Specialty(id=str(m.id), name=m.name, is_basic_cycle=m.is_basic_cycle)

    def get_all(self) -> List[Specialty]:
        rows = self.db.query(SpecialtyModel).order_by(SpecialtyModel.name).all()
        return [self._to_entity(r) for r in rows]

    def get_by_id(self, id: str) -> Optional[Specialty]:
        m = self.db.query(SpecialtyModel).filter(SpecialtyModel.id == id).first()
        return self._to_entity(m) if m else None


class SchoolSettingsRepositoryImpl(SchoolSettingsRepository):
    def __init__(self, db: Session):
        self.db = db

    def get(self) -> SchoolSettings:
        m = self.db.query(SchoolSettingsModel).first()
        if m is None:
            # Red de seguridad: si por algún motivo la fila sembrada no
            # está, no rompemos el desplegable — usamos los defaults.
            return SchoolSettings(max_grade_year=7, max_division=4)
        return SchoolSettings(
            max_grade_year=m.max_grade_year, max_division=m.max_division,
            consecutive_absences_alert_threshold=m.consecutive_absences_alert_threshold,
            preceptor_temp_assignment_alert_days=m.preceptor_temp_assignment_alert_days,
            schedule_exception_alert_days=m.schedule_exception_alert_days,
        )
