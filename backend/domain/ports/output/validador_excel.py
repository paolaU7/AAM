from typing import Protocol
from dataclasses import dataclass
from datetime import time


@dataclass
class HorarioRaw:
    """Representación intermedia del horario parseado desde Excel."""
    id_curso:             str
    fecha_vigencia_desde: str   # ISO date string — validado antes
    hora_inicio:          time
    limite_presente:      time
    limite_cuarto:        time
    limite_medio:         time


class ValidadorEsquemaExcel(Protocol):
    def validar(self, archivo: bytes) -> list[str]: ...
    """
    Retorna lista de errores de formato.
    Lista vacía indica que el archivo es válido.
    """

    def parsear(self, archivo: bytes) -> list[HorarioRaw]: ...
    """
    Solo se llama si validar() retornó lista vacía.
    """
