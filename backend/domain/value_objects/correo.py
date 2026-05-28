import re
from dataclasses import dataclass


_PATRON_CORREO = re.compile(r"^[\w\.\+\-]+@[\w\-]+\.[a-z]{2,}$", re.IGNORECASE)


@dataclass(frozen=True)
class Correo:
    valor: str

    def __post_init__(self) -> None:
        if not _PATRON_CORREO.match(self.valor):
            raise ValueError(f"Correo inválido: '{self.valor}'.")

    def __str__(self) -> str:
        return self.valor.lower()
