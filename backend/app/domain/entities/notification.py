from dataclasses import dataclass


@dataclass(frozen=True)
class Notification:
    """Alerta calculada al vuelo para el panel de notificaciones (campana
    del header) — no se persiste en ninguna tabla, se recalcula cada vez
    que se abre el desplegable. `message` ya viene armado en texto listo
    para mostrar; el frontend solo elige ícono/color según `type`."""

    type: str  # 'preceptor_temp_assignment' | 'schedule_exception' | 'consecutive_absences'
    message: str
