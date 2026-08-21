from dataclasses import dataclass
from typing import List, Optional
from app.domain.entities.user import Usuario, RolUsuario
from app.domain.repositories.user_repository import UsuarioRepository


class AltaUsuarioError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


class GetUsuarios:
    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    def execute(self) -> List[Usuario]:
        return self.repo.get_usuarios()


@dataclass
class CreateUserResult:
    usuario: Usuario
    temporary_password: str


class CrearUsuario:
    """Solo dirección crea cuentas (impuesto por el frontend/rol de quien
    llama, no acá). El email y la contraseña inicial se generan en el
    backend — la contraseña se devuelve una única vez."""

    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    def execute(self, *, nombre: str, apellido: str, rol: RolUsuario) -> CreateUserResult:
        nombre = (nombre or "").strip()
        apellido = (apellido or "").strip()
        if not nombre or not apellido:
            raise AltaUsuarioError("Nombre y apellido son obligatorios.", 400)

        usuario, password = self.repo.crear_usuario(nombre, apellido, rol)
        return CreateUserResult(usuario=usuario, temporary_password=password)


class ToggleActive:
    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    def execute(self, id: str) -> Optional[Usuario]:
        return self.repo.toggle_active(id)


class ResetPassword:
    def __init__(self, repo: UsuarioRepository):
        self.repo = repo

    def execute(self, id: str) -> Optional[str]:
        return self.repo.reset_password(id)
