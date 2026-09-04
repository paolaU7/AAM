from typing import List
from app.domain.entities.notification import Notification
from app.domain.repositories.notification_repository import NotificationRepository
from app.domain.repositories.specialty_repository import SchoolSettingsRepository


class GetAlerts:
    def __init__(self, repo: NotificationRepository, settings_repo: SchoolSettingsRepository):
        self.repo = repo
        self.settings_repo = settings_repo

    def execute(self) -> List[Notification]:
        settings = self.settings_repo.get()
        return self.repo.get_alerts(
            preceptor_temp_assignment_alert_days=settings.preceptor_temp_assignment_alert_days,
            schedule_exception_alert_days=settings.schedule_exception_alert_days,
            consecutive_absences_alert_threshold=settings.consecutive_absences_alert_threshold,
        )
