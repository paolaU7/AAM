from typing import Protocol


class AuthSecundariaPort(Protocol):
    """
    Puerto abstracto de autenticación secundaria.
    V1: implementado por AdaptadorQR.
    Extensible a PIN, huella, facial sin modificar el dominio.
    """
    def verificar(self, credencial: str, id_alumno: str) -> bool: ...
