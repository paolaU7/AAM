from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.usuario import Usuario

class UsuarioRepository(ABC):

    @abstractmethod
    def get_usuarios(self) -> List[Usuario]: ...

    @abstractmethod
    def get_usuario_por_id(self, id: str) -> Optional[Usuario]: ...

    @abstractmethod
    def get_usuario_por_username(self, username: str) -> Optional[Usuario]: ...

    @abstractmethod
    def crear_usuario(self, usuario: Usuario) -> Usuario: ...