from dataclasses import dataclass
from ..value_objects import Correo, Rol


@dataclass
class Usuario:
    id:            str     # ULID
    correo:        Correo
    password_hash: str
    rol:           Rol
