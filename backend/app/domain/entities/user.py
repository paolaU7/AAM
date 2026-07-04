from dataclasses import dataclass
from enum import Enum
from typing import Optional
import re

class RolUsuario(str, Enum):
    direccion = "direccion"
    preceptor = "preceptor"

@dataclass(frozen=True)
class Usuario:
    id: str
    nombre: str
    apellido: str
    username: str
    rol: RolUsuario
    activo: bool
    turno: Optional[str] = None

    @property
    def nombre_completo(self) -> str:
        return f"{self.apellido}, {self.nombre}"

    @staticmethod
    def generar_username(apellido: str, nombre: str) -> str:
        def limpiar(s: str) -> str:
            s = s.lower()
            for src, dst in [('áàä','a'),('éèë','e'),('íìï','i'),('óòö','o'),('úùü','u'),('ñ','n')]:
                for c in src:
                    s = s.replace(c, dst)
            return re.sub(r'[^a-z]', '', s)

        a = limpiar(apellido)[:3]
        n = limpiar(nombre)[:3]
        return f"{a}.{n}"