from dataclasses import dataclass


@dataclass(frozen=True)
class UIDPulsera:
    valor: str

    def __post_init__(self) -> None:
        if not self.valor.strip():
            raise ValueError("El UID de pulsera no puede estar vacío.")

    def __str__(self) -> str:
        return self.valor
