from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
from app.infrastructure.database import get_db
from app.infrastructure.repositories.user_repository_impl import UsuarioRepositoryImpl
from app.domain.usecases.user_usecases import (
    GetUsuarios, CrearUsuario, ToggleActive, ResetPassword,
    ActualizarUsuario, EliminarUsuario, AltaUsuarioError,
)
from app.domain.entities.user import Usuario, RolUsuario


class UserResponse(BaseModel):
    id: str
    nombre: str
    apellido: str
    nombre_completo: str
    username: str
    email: str
    rol: str
    activo: bool


class UserCreate(BaseModel):
    nombre: str
    apellido: str
    rol: str  # 'principal' | 'preceptor'


class UserUpdate(BaseModel):
    nombre: str
    apellido: str
    rol: str  # 'principal' | 'preceptor'


class UserCreateResponse(BaseModel):
    usuario: UserResponse
    password_temporal: str


class ResetPasswordResponse(BaseModel):
    password_temporal: str


router = APIRouter(prefix="/users", tags=["users"])


def _to_response(u: Usuario) -> UserResponse:
    return UserResponse(
        id=u.id, nombre=u.nombre, apellido=u.apellido,
        nombre_completo=u.nombre_completo, username=u.username,
        email=u.email, rol=u.rol.value, activo=u.activo,
    )


@router.get("", response_model=List[UserResponse])
def get_users(db: Session = Depends(get_db)):
    repo = UsuarioRepositoryImpl(db)
    return [_to_response(u) for u in GetUsuarios(repo).execute()]


@router.post("", response_model=UserCreateResponse, status_code=201)
def crear_usuario(body: UserCreate, db: Session = Depends(get_db)):
    try:
        rol = RolUsuario(body.rol)
    except ValueError:
        raise HTTPException(status_code=400, detail="Rol inválido. Debe ser 'principal' o 'preceptor'.")

    repo = UsuarioRepositoryImpl(db)
    try:
        result = CrearUsuario(repo).execute(nombre=body.nombre, apellido=body.apellido, rol=rol)
    except AltaUsuarioError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return UserCreateResponse(
        usuario=_to_response(result.usuario),
        password_temporal=result.temporary_password,
    )


@router.post("/{id}/toggle-active", response_model=UserResponse)
def toggle_active(id: str, db: Session = Depends(get_db)):
    repo = UsuarioRepositoryImpl(db)
    usuario = ToggleActive(repo).execute(id)
    if usuario is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return _to_response(usuario)


@router.post("/{id}/reset-password", response_model=ResetPasswordResponse)
def reset_password(id: str, db: Session = Depends(get_db)):
    repo = UsuarioRepositoryImpl(db)
    password = ResetPassword(repo).execute(id)
    if password is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return ResetPasswordResponse(password_temporal=password)


@router.put("/{id}", response_model=UserResponse)
def actualizar_usuario(id: str, body: UserUpdate, db: Session = Depends(get_db)):
    try:
        rol = RolUsuario(body.rol)
    except ValueError:
        raise HTTPException(status_code=400, detail="Rol inválido. Debe ser 'principal' o 'preceptor'.")

    repo = UsuarioRepositoryImpl(db)
    try:
        usuario = ActualizarUsuario(repo).execute(id, nombre=body.nombre, apellido=body.apellido, rol=rol)
    except AltaUsuarioError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    if usuario is None:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return _to_response(usuario)


@router.delete("/{id}", status_code=204)
def eliminar_usuario(id: str, db: Session = Depends(get_db)):
    """Borrado físico — puede rechazarse (409) si el usuario tiene registros
    asociados. Para revocar acceso sin perder historial, usar toggle-active."""
    repo = UsuarioRepositoryImpl(db)
    try:
        ok = EliminarUsuario(repo).execute(id)
    except AltaUsuarioError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    if not ok:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return None
