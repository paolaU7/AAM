from dataclasses import dataclass
from datetime import date
from ..value_objects import FranjasHorarias


@dataclass
class Horario:
    id:                   str             # ULID
    id_curso:             str             # ULID → Curso
    fecha_vigencia_desde: date
    franjas:              FranjasHorarias
