from dataclasses import dataclass
from ..value_objects import DNI, NombreCompleto, UIDPulsera


@dataclass
class Alumno:
    id:          str              # ULID
    nombre:      NombreCompleto
    dni:         DNI
    uid_pulsera: UIDPulsera
    id_curso:    str              # ULID → Curso
