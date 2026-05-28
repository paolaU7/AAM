from datetime import datetime
from ..models.registro_asistencia import RegistroAsistencia
from ..models.horario             import Horario
from .horario_vigente             import horarioVigente
from ..models.excepcion_horario   import ExcepcionHorario


def esDuplicado(
    id_alumno:    str,
    timestamp:    datetime,
    existentes:   list[RegistroAsistencia],
    horarios:     list[Horario],
    excepciones:  list[ExcepcionHorario],
    id_curso:     str,
) -> bool:
    """
    Determina si ya existe un registro para el alumno en el mismo turno.
    La ventana de ignorado es el turno completo (desde hora_inicio
    hasta medianoche del mismo día).
    Función pura — sin efectos laterales.
    """
    fecha = timestamp.date()
    horario_base, excepcion_activa = horarioVigente(
        id_curso, fecha, horarios, excepciones
    )

    if not horario_base:
        return False

    franjas = (
        excepcion_activa.franjas
        if excepcion_activa and excepcion_activa.franjas
        else horario_base.franjas
    )

    inicio_turno = datetime.combine(fecha, franjas.hora_inicio)

    return any(
        r.id_alumno == id_alumno
        and r.timestamp_escaneo >= inicio_turno
        and r.timestamp_escaneo.date() == fecha
        for r in existentes
    )
