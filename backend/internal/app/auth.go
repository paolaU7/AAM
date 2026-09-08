package app

import (
	"context"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// AuthService is the (minimal, new) panel login flow: username + password ->
// session token carrying the user's role. Scaffolding for role-gated access;
// the existing endpoints are not yet closed off (that would break the current
// Flutter app, out of scope for the migration pass).
type AuthService struct {
	Users  domain.UserRepo
	Hasher domain.PasswordHasher
	Tokens domain.TokenIssuer
}

// Login validates the credentials and returns a Session on success.
func (s AuthService) Login(ctx context.Context, username, password string) (domain.Session, error) {
	username = strings.TrimSpace(strings.ToLower(username))
	if username == "" || password == "" {
		return domain.Session{}, domain.NewDomainError("Usuario y contraseña son obligatorios.", 400)
	}
	auth, err := s.Users.FindAuthByUsername(ctx, username)
	if err != nil {
		return domain.Session{}, err
	}
	if auth == nil || !s.Hasher.Compare(auth.PasswordHash, password) {
		return domain.Session{}, domain.NewDomainError("Usuario o contraseña incorrectos.", 401)
	}
	if !auth.User.Activo {
		return domain.Session{}, domain.NewDomainError("La cuenta está deshabilitada.", 403)
	}
	token, err := s.Tokens.Issue(auth.User)
	if err != nil {
		return domain.Session{}, err
	}
	return domain.Session{User: auth.User, Token: token}, nil
}
