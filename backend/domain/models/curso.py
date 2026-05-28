from dataclasses import dataclass
from ..value_objects import Turno


@dataclass
class Curso:
    id:     str    # ULID
    nombre: str
    turno:  Turno
