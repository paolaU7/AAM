from enum import Enum


class Turno(str, Enum):
    MAÑANA     = "mañana"
    TARDE      = "tarde"
    VESPERTINO = "vespertino"
