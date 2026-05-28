from datetime import datetime
from ..models.horario           import Horario
from ..models.excepcion_horario import ExcepcionHorario
from ..value_objects            import EstadoAsistencia, FranjasHorarias


def estadoDeAsistencia(
    timestamp:  datetime,
    horario:    Horario,
    excepcion:  ExcepcionHorario | None,
) -> EstadoAsistencia:
    """
    Determina el estado de asistencia comparando el timestamp del escaneo
    contra las franjas horarias vigentes del curso.
    Función pura — sin efectos laterales.
    """
    franjas: FranjasHorarias = (
        excepcion.franjas
        if excepcion and excepcion.franjas
        else horario.franjas
    )

    hora = timestamp.time()

    if hora <= franjas.limite_presente:
        return EstadoAsistencia.PRESENTE
    if hora <= franjas.limite_cuarto:
        return EstadoAsistencia.TARDE_CUARTO
    if hora <= franjas.limite_medio:
        return EstadoAsistencia.TARDE_MEDIO
    return EstadoAsistencia.AUSENTE_CON_PERM
