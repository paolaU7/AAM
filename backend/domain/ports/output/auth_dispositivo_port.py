from typing import Protocol


class AuthDispositivoPort(Protocol):
    """
    Puerto abstracto de autenticación para dispositivos lectores.
    V1: implementado por AdaptadorAPIKey.
    V2: reemplazable por AdaptadorJWTDevice sin modificar el dominio.
    """
    def verificar(self, credencial: str) -> bool: ...
