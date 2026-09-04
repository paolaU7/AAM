from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.notification_repository_impl import NotificationRepositoryImpl
from app.infrastructure.repositories.specialty_repository_impl import SchoolSettingsRepositoryImpl
from app.domain.usecases.notification_usecases import GetAlerts


class NotificationResponse(BaseModel):
    type: str
    message: str


router = APIRouter(tags=["notifications"])


@router.get("/notifications", response_model=List[NotificationResponse])
def get_notifications(db: Session = Depends(get_db)):
    repo = NotificationRepositoryImpl(db)
    settings_repo = SchoolSettingsRepositoryImpl(db)
    alerts = GetAlerts(repo, settings_repo).execute()
    return [NotificationResponse(type=a.type, message=a.message) for a in alerts]
