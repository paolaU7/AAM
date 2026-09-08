package app

import (
	"context"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// UserService covers user_usecases.py. Only dirección creates accounts
// (enforced by the frontend/role of the caller, not here). Email and initial
// password are generated in the repo; the password is returned once.
type UserService struct {
	Repo domain.UserRepo
}

// CreateUserResult carries the one-time plaintext password.
type CreateUserResult struct {
	Usuario           domain.Usuario
	TemporaryPassword string
}

func (s UserService) List(ctx context.Context) ([]domain.Usuario, error) {
	return s.Repo.GetUsuarios(ctx)
}

func (s UserService) Create(ctx context.Context, nombre, apellido string, rol domain.RolUsuario) (CreateUserResult, error) {
	nombre = strings.TrimSpace(nombre)
	apellido = strings.TrimSpace(apellido)
	if nombre == "" || apellido == "" {
		return CreateUserResult{}, domain.NewDomainError("Nombre y apellido son obligatorios.", 400)
	}
	u, pw, err := s.Repo.CrearUsuario(ctx, nombre, apellido, rol)
	if err != nil {
		return CreateUserResult{}, err
	}
	return CreateUserResult{Usuario: u, TemporaryPassword: pw}, nil
}

func (s UserService) ToggleActive(ctx context.Context, id string) (*domain.Usuario, error) {
	return s.Repo.ToggleActive(ctx, id)
}

func (s UserService) ResetPassword(ctx context.Context, id string) (*string, error) {
	return s.Repo.ResetPassword(ctx, id)
}

func (s UserService) Update(ctx context.Context, id, nombre, apellido string, rol domain.RolUsuario) (*domain.Usuario, error) {
	nombre = strings.TrimSpace(nombre)
	apellido = strings.TrimSpace(apellido)
	if nombre == "" || apellido == "" {
		return nil, domain.NewDomainError("Nombre y apellido son obligatorios.", 400)
	}
	return s.Repo.ActualizarUsuario(ctx, id, nombre, apellido, rol)
}

// Delete is EliminarUsuario. The repo returns a *domain.DomainError (409) when
// the user has associated records.
func (s UserService) Delete(ctx context.Context, id string) (bool, error) {
	return s.Repo.EliminarUsuario(ctx, id)
}
