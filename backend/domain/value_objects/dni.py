import re
from dataclasses import dataclass


_PATRON_DNI = re.compile(r"^\d{7,8}$")


@dataclass(frozen=True)
class DNI:
    valor: str

    def __post_init__(self) -> None:
        if not _PATRON_DNI.match(self.valor):
            raise ValueError(f"DNI inválido: '{self.valor}'. Debe contener 7 u 8 dígitos.")

    def __str__(self) -> str:
        return self.valor
