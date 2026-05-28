from __future__ import annotations
from dataclasses import dataclass
from datetime import date, datetime
from ..value_objects import TipoExcepcion, FranjasHorarias


@dataclass
class ExcepcionHorario:
    id:            str                      # ULID
    id_curso:      str                      # ULID → Curso
    id_preceptor:  str                      # ULID → Usuario
    fecha_desde:   date
    fecha_hasta:   date                     # == fecha_desde si es un día
    tipo:          TipoExcepcion
    franjas:       FranjasHorarias | None   # None = sin cambio de franjas
    creado_en:     datetime

    def abarca(self, fecha: date) -> bool:
        return self.fecha_desde <= fecha <= self.fecha_hasta
