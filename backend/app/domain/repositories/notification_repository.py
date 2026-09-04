from abc import ABC, abstractmethod
from typing import List
from app.domain.entities.notification import Notification


class NotificationRepository(ABC):

    @abstractmethod
    def get_alerts(
        self,
        *,
        preceptor_temp_assignment_alert_days: int,
        schedule_exception_alert_days: int,
        consecutive_absences_alert_threshold: int,
    ) -> List[Notification]:
        """Combina las 3 categorías de alerta en una sola lista, calculada
        contra los datos actuales — nada de esto se persiste."""
        ...
