from dataclasses import dataclass
from datetime import datetime
from ..value_objects import EstadoAsistencia, MetodoRegistro


@dataclass
class RegistroAsistencia:
    id:                str               # ULID — generado en el lector
    id_alumno:         str               # ULID → Alumno
    id_lector:         str               # ULID → Lector
    timestamp_escaneo: datetime          # hora real del escaneo
    estado:            EstadoAsistencia
    metodo:            MetodoRegistro
