from __future__ import annotations
from dataclasses import dataclass
from datetime import time


@dataclass(frozen=True)
class FranjasHorarias:
    hora_inicio:      time
    limite_presente:  time   # hasta aquí es PRESENTE
    limite_cuarto:    time   # hasta aquí es TARDE ¼ falta
    limite_medio:     time   # hasta aquí es TARDE ½ falta
                             # pasado límite_medio → AUSENTE CON PERMANENCIA

    def __post_init__(self) -> None:
        if not (self.hora_inicio
                < self.limite_presente
                <= self.limite_cuarto
                <= self.limite_medio):
            raise ValueError(
                "Las franjas horarias deben respetar el orden: "
                "hora_inicio < limite_presente ≤ limite_cuarto ≤ limite_medio."
            )
