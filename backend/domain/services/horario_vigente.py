from datetime import date
from ..models.horario           import Horario
from ..models.excepcion_horario import ExcepcionHorario


def horarioVigente(
    id_curso:    str,
    fecha:       date,
    horarios:    list[Horario],
    excepciones: list[ExcepcionHorario],
) -> tuple[Horario | None, ExcepcionHorario | None]:
    """
    Retorna el horario base vigente y la excepción activa para un curso
    en una fecha dada. La excepción más reciente tiene prioridad en caso
    de solapamiento.
    Función pura — sin efectos laterales.
    """
    horario_base = _horarioBase(id_curso, fecha, horarios)

    excepcion_activa = _excepcionActiva(id_curso, fecha, excepciones)

    return horario_base, excepcion_activa


def _horarioBase(
    id_curso:  str,
    fecha:     date,
    horarios:  list[Horario],
) -> Horario | None:
    candidatos = [
        h for h in horarios
        if h.id_curso == id_curso and h.fecha_vigencia_desde <= fecha
    ]
    if not candidatos:
        return None
    return max(candidatos, key=lambda h: h.fecha_vigencia_desde)


def _excepcionActiva(
    id_curso:    str,
    fecha:       date,
    excepciones: list[ExcepcionHorario],
) -> ExcepcionHorario | None:
    candidatas = [
        e for e in excepciones
        if e.id_curso == id_curso and e.abarca(fecha)
    ]
    if not candidatas:
        return None
    # La excepción creada más recientemente tiene prioridad
    return max(candidatas, key=lambda e: e.creado_en)
