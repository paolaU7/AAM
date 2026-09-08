package domain

import "context"

// ── Secondary authentication (extension point) ───────────────────────────────
//
// V1 ships exactly one secondary method: a static QR shown by the student,
// verified when the reader has connectivity. The requirement is that adding
// more methods later (fingerprint, PIN, rotating code...) must NOT touch the
// domain or the use cases — only register a new SecondaryAuthenticator.

// SecondaryCredential is the opaque proof a student presents for the second
// factor. `Method` selects the authenticator; `Value` is method-specific
// (the QR payload, a PIN, ...).
type SecondaryCredential struct {
	Method string
	Value  string
}

// SecondaryAuthenticator verifies one kind of secondary credential for a
// student. Implementations live in the adapter layer.
type SecondaryAuthenticator interface {
	// Method is the stable identifier this authenticator handles
	// (e.g. "qr_static"). It is matched against SecondaryCredential.Method.
	Method() string
	// Verify returns nil when the credential proves the student's identity,
	// or a *DomainError (401) otherwise.
	Verify(ctx context.Context, studentID string, cred SecondaryCredential) error
}

// SecondaryAuthRegistry dispatches a credential to the authenticator that
// handles its method. New methods are added by registering another
// SecondaryAuthenticator here — nothing else in the domain changes.
type SecondaryAuthRegistry struct {
	byMethod map[string]SecondaryAuthenticator
}

func NewSecondaryAuthRegistry(auths ...SecondaryAuthenticator) *SecondaryAuthRegistry {
	r := &SecondaryAuthRegistry{byMethod: make(map[string]SecondaryAuthenticator, len(auths))}
	for _, a := range auths {
		r.byMethod[a.Method()] = a
	}
	return r
}

func (r *SecondaryAuthRegistry) Register(a SecondaryAuthenticator) {
	r.byMethod[a.Method()] = a
}

// Verify routes cred to the matching authenticator.
func (r *SecondaryAuthRegistry) Verify(ctx context.Context, studentID string, cred SecondaryCredential) error {
	a, ok := r.byMethod[cred.Method]
	if !ok {
		return NewDomainError("Método de autenticación secundaria no soportado.", 400)
	}
	return a.Verify(ctx, studentID, cred)
}

// Methods lists the registered method identifiers (for diagnostics/UI).
func (r *SecondaryAuthRegistry) Methods() []string {
	out := make([]string, 0, len(r.byMethod))
	for m := range r.byMethod {
		out = append(out, m)
	}
	return out
}

// ── Panel user authentication ────────────────────────────────────────────────

// Session is what a successful panel login yields.
type Session struct {
	User  Usuario
	Token string
}

// TokenIssuer mints and validates opaque session tokens for panel users. The
// concrete implementation (JWT, ...) lives in the adapter layer.
type TokenIssuer interface {
	Issue(u Usuario) (string, error)
	Parse(token string) (userID string, rol RolUsuario, err error)
}

// PasswordHasher abstracts the password KDF so the domain/use cases never see
// bcrypt directly.
type PasswordHasher interface {
	Hash(plain string) (string, error)
	Compare(hash, plain string) bool
}
