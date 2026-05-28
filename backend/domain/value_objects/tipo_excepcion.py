from enum import Enum


class TipoExcepcion(str, Enum):
    FERIADO          = "feriado"
    DOCENTE_AUSENTE  = "docente_ausente"
    CAMBIO_TEMPORAL  = "cambio_temporal"
