from dataclasses import dataclass


@dataclass(frozen=True)
class NombreCompleto:
    nombre:   str
    apellido: str

    def __post_init__(self) -> None:
        if not self.nombre.strip():
            raise ValueError("El nombre no puede estar vacío.")
        if not self.apellido.strip():
            raise ValueError("El apellido no puede estar vacío.")

    def __str__(self) -> str:
        return f"{self.apellido}, {self.nombre}"
