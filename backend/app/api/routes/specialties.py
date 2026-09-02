from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.specialty_repository_impl import (
    SpecialtyRepositoryImpl, SchoolSettingsRepositoryImpl,
)
from app.domain.usecases.specialty_usecases import GetSpecialties, GetSchoolSettings


class SpecialtyResponse(BaseModel):
    id: str
    name: str
    is_basic_cycle: bool


class SchoolSettingsResponse(BaseModel):
    max_grade_year: int
    max_division: int


router = APIRouter(tags=["specialties"])


@router.get("/specialties", response_model=List[SpecialtyResponse])
def get_specialties(db: Session = Depends(get_db)):
    repo = SpecialtyRepositoryImpl(db)
    rows = GetSpecialties(repo).execute()
    return [SpecialtyResponse(id=r.id, name=r.name, is_basic_cycle=r.is_basic_cycle) for r in rows]


@router.get("/school-settings", response_model=SchoolSettingsResponse)
def get_school_settings(db: Session = Depends(get_db)):
    repo = SchoolSettingsRepositoryImpl(db)
    s = GetSchoolSettings(repo).execute()
    return SchoolSettingsResponse(max_grade_year=s.max_grade_year, max_division=s.max_division)
