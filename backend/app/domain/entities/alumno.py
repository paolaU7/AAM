from dataclasses import dataclass
from typing import Optional


@dataclass
class Alumno:
    id: Optional[int]
    nombre: str
    apellido: str
    dni: str
    curso: str
    especialidad: Optional[str] = None
    recursante: bool = False
