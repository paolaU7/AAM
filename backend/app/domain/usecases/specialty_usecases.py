from typing import List
from app.domain.entities.specialty import Specialty, SchoolSettings
from app.domain.repositories.specialty_repository import SpecialtyRepository, SchoolSettingsRepository


class GetSpecialties:
    def __init__(self, repo: SpecialtyRepository):
        self.repo = repo

    def execute(self) -> List[Specialty]:
        return self.repo.get_all()


class GetSchoolSettings:
    def __init__(self, repo: SchoolSettingsRepository):
        self.repo = repo

    def execute(self) -> SchoolSettings:
        return self.repo.get()
