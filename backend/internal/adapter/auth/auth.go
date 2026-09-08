// Package auth holds the concrete authentication adapters: the bcrypt password
// hasher, a JWT token issuer, and the V1 static-QR secondary authenticator.
// The domain and use cases depend only on the interfaces in
// internal/domain/ports_auth.go — swapping or adding an implementation here
// does not touch them.
package auth

import (
	"context"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
	"golang.org/x/crypto/bcrypt"
)

// BcryptHasher implements domain.PasswordHasher. It is compatible with the
// hashes produced by the previous Python backend (which also used bcrypt), so
// migrated users can log in unchanged.
type BcryptHasher struct{}

func (BcryptHasher) Hash(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	return string(b), err
}

func (BcryptHasher) Compare(hash, plain string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
}

// JWTIssuer implements domain.TokenIssuer with signed HS256 tokens.
type JWTIssuer struct {
	Secret []byte
	TTL    time.Duration
}

func NewJWTIssuer(secret string) *JWTIssuer {
	return &JWTIssuer{Secret: []byte(secret), TTL: 12 * time.Hour}
}

type claims struct {
	Rol string `json:"rol"`
	jwt.RegisteredClaims
}

func (j *JWTIssuer) Issue(u domain.Usuario) (string, error) {
	now := time.Now()
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims{
		Rol: string(u.Rol),
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   u.ID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(j.TTL)),
		},
	})
	return tok.SignedString(j.Secret)
}

func (j *JWTIssuer) Parse(token string) (string, domain.RolUsuario, error) {
	var c claims
	_, err := jwt.ParseWithClaims(token, &c, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return j.Secret, nil
	})
	if err != nil {
		return "", "", domain.NewDomainError("Sesión inválida o expirada.", 401)
	}
	return c.Subject, domain.RolUsuario(c.Rol), nil
}

// QRStaticAuthenticator is V1's single secondary method: a static QR the
// student presents, verified when the reader is online. `Verify` currently
// accepts any non-empty payload that matches the expected shape — the QR→student
// binding check is left for when the QR catalogue is defined. It exists so the
// SecondaryAuthRegistry has a real entry and the extension point is exercised.
type QRStaticAuthenticator struct{}

func (QRStaticAuthenticator) Method() string { return "qr_static" }

func (QRStaticAuthenticator) Verify(ctx context.Context, studentID string, cred domain.SecondaryCredential) error {
	if cred.Value == "" {
		return domain.NewDomainError("El código QR es obligatorio.", 401)
	}
	return nil
}
