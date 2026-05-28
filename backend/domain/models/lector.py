from dataclasses import dataclass


@dataclass
class Lector:
    id:        str    # ULID
    ubicacion: str
    activo:    bool
