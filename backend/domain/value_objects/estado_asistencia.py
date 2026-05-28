from enum import Enum


class EstadoAsistencia(str, Enum):
    PRESENTE          = "presente"
    TARDE_CUARTO      = "tarde_cuarto"       # 10 – 20 min
    TARDE_MEDIO       = "tarde_medio"        # 20 – 60 min
    AUSENTE_CON_PERM  = "ausente_con_perm"   # más de 60 min
    MANUAL            = "manual"             # ingresado por preceptor
