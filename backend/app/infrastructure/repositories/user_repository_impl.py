import secrets
import string
from typing import List, Optional, Tuple
import bcrypt
from sqlalchemy.orm import Session
from app.domain.entities.user import Usuario, RolUsuario
from app.domain.repositories.user_repository import UsuarioRepository
from app.infrastructure.models.user_model import UserModel, UserRoleEnum

EMAIL_DOMAIN = "aam.edu.ar"  # placeholder — reemplazar por el dominio real de la institución


def _generar_password() -> str:
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(10))


def _hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


class UsuarioRepositoryImpl(UsuarioRepository):

    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _to_entity(model: UserModel) -> Usuario:
        apellido, _, nombre = model.full_name.partition(", ")
        return Usuario(
            id=str(model.id),
            nombre=nombre,
            apellido=apellido,
            email=model.email,
            rol=RolUsuario(model.role.value),
            activo=model.is_active,
        )

    def _email_unico(self, username: str) -> str:
        suffix = 0
        while True:
            local = username if suffix == 0 else f"{username}{suffix}"
            email = f"{local}@{EMAIL_DOMAIN}"
            existe = self.db.query(UserModel).filter(UserModel.email == email).first()
            if existe is None:
                return email
            suffix += 1

    def get_usuarios(self) -> List[Usuario]:
        rows = self.db.query(UserModel).order_by(UserModel.full_name).all()
        return [self._to_entity(u) for u in rows]

    def get_usuario_por_id(self, id: str) -> Optional[Usuario]:
        model = self.db.query(UserModel).filter(UserModel.id == id).first()
        return self._to_entity(model) if model else None

    def crear_usuario(self, nombre: str, apellido: str, rol: RolUsuario) -> Tuple[Usuario, str]:
        username = Usuario.generar_username(apellido, nombre)
        email = self._email_unico(username)
        password = _generar_password()

        model = UserModel(
            email=email,
            password_hash=_hash_password(password),
            full_name=f"{apellido}, {nombre}",
            role=UserRoleEnum(rol.value),
            is_active=True,
        )
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model), password

    def toggle_active(self, id: str) -> Optional[Usuario]:
        model = self.db.query(UserModel).filter(UserModel.id == id).first()
        if model is None:
            return None
        model.is_active = not model.is_active
        self.db.commit()
        self.db.refresh(model)
        return self._to_entity(model)

    def reset_password(self, id: str) -> Optional[str]:
        model = self.db.query(UserModel).filter(UserModel.id == id).first()
        if model is None:
            return None
        password = _generar_password()
        model.password_hash = _hash_password(password)
        self.db.commit()
        return password
