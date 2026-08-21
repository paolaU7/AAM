from abc import ABC, abstractmethod
from typing import List, Optional, Tuple
from app.domain.entities.user import Usuario, RolUsuario


class UsuarioRepository(ABC):

    @abstractmethod
    def get_usuarios(self) -> List[Usuario]: ...

    @abstractmethod
    def get_usuario_por_id(self, id: str) -> Optional[Usuario]: ...

    @abstractmethod
    def crear_usuario(self, nombre: str, apellido: str, rol: RolUsuario) -> Tuple[Usuario, str]:
        """Crea el usuario con email/username derivados del nombre y una
        contraseña inicial generada al azar. Devuelve (usuario, password_en_texto_plano)
        — la contraseña solo se expone esta vez, nunca se vuelve a poder leer."""
        ...

    @abstractmethod
    def toggle_active(self, id: str) -> Optional[Usuario]: ...

    @abstractmethod
    def reset_password(self, id: str) -> Optional[str]:
        """Genera y persiste una nueva contraseña; devuelve el texto plano
        (o None si el usuario no existe)."""
        ...
