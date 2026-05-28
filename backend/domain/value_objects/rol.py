from enum import Enum


class Rol(str, Enum):
    DIRECCION   = "direccion"
    PRECEPTOR   = "preceptor"
    DISPOSITIVO = "dispositivo"
