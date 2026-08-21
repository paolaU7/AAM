from dataclasses import dataclass
from enum import Enum
import re

class RolUsuario(str, Enum):
    principal = "principal"
    preceptor = "preceptor"

@dataclass(frozen=True)
class Usuario:
    id: str
    nombre: str
    apellido: str
    email: str
    rol: RolUsuario
    activo: bool

    @property
    def nombre_completo(self) -> str:
        return f"{self.apellido}, {self.nombre}"

    @property
    def username(self) -> str:
        return Usuario.generar_username(self.apellido, self.nombre)

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
