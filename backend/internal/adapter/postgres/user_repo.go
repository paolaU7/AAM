package postgres

import (
	"context"
	"crypto/rand"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
	"golang.org/x/crypto/bcrypt"
)

// emailDomain is a placeholder — replace with the institution's real domain.
const emailDomain = "aam.edu.ar"

type UserRepo struct{ pool *pgxpool.Pool }

func NewUserRepo(pool *pgxpool.Pool) *UserRepo { return &UserRepo{pool} }

func scanUsuario(row pgx.Row) (domain.Usuario, error) {
	var u domain.Usuario
	var fullName, role string
	if err := row.Scan(&u.ID, &u.Email, &fullName, &role, &u.Activo); err != nil {
		return domain.Usuario{}, err
	}
	// full_name is stored "Apellido, Nombre".
	u.Apellido, u.Nombre = splitFullName(fullName)
	u.Rol = domain.RolUsuario(role)
	return u, nil
}

func splitFullName(fullName string) (apellido, nombre string) {
	if a, n, ok := strings.Cut(fullName, ", "); ok {
		return a, n
	}
	return fullName, ""
}

const userSelect = `SELECT id, email, full_name, role::text, is_active FROM users`

func (r *UserRepo) GetUsuarios(ctx context.Context) ([]domain.Usuario, error) {
	rows, err := r.pool.Query(ctx, userSelect+" ORDER BY full_name")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Usuario
	for rows.Next() {
		u, err := scanUsuario(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

func (r *UserRepo) GetUsuarioPorID(ctx context.Context, id string) (*domain.Usuario, error) {
	u, err := scanUsuario(r.pool.QueryRow(ctx, userSelect+" WHERE id = $1", id))
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepo) uniqueEmail(ctx context.Context, username string) (string, error) {
	for suffix := 0; ; suffix++ {
		local := username
		if suffix > 0 {
			local = fmt.Sprintf("%s%d", username, suffix)
		}
		email := local + "@" + emailDomain
		var exists bool
		if err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)`, email).Scan(&exists); err != nil {
			return "", err
		}
		if !exists {
			return email, nil
		}
	}
}

func (r *UserRepo) CrearUsuario(ctx context.Context, nombre, apellido string, rol domain.RolUsuario) (domain.Usuario, string, error) {
	username := domain.GenerarUsername(apellido, nombre)
	email, err := r.uniqueEmail(ctx, username)
	if err != nil {
		return domain.Usuario{}, "", err
	}
	password := generatePassword()
	hash, err := hashPassword(password)
	if err != nil {
		return domain.Usuario{}, "", err
	}
	var id string
	err = r.pool.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, full_name, role, is_active)
		 VALUES ($1, $2, $3, $4::user_role, TRUE) RETURNING id`,
		email, hash, apellido+", "+nombre, string(rol)).Scan(&id)
	if err != nil {
		return domain.Usuario{}, "", mapDBError(err, "No se pudo crear el usuario.")
	}
	u, err := r.GetUsuarioPorID(ctx, id)
	if err != nil || u == nil {
		return domain.Usuario{}, "", err
	}
	return *u, password, nil
}

func (r *UserRepo) ToggleActive(ctx context.Context, id string) (*domain.Usuario, error) {
	tag, err := r.pool.Exec(ctx, `UPDATE users SET is_active = NOT is_active, updated_at = now() WHERE id = $1`, id)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetUsuarioPorID(ctx, id)
}

func (r *UserRepo) ActualizarUsuario(ctx context.Context, id, nombre, apellido string, rol domain.RolUsuario) (*domain.Usuario, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE users SET full_name = $2, role = $3::user_role, updated_at = now() WHERE id = $1`,
		id, apellido+", "+nombre, string(rol))
	if err != nil {
		return nil, mapDBError(err, "No se pudo actualizar el usuario.")
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetUsuarioPorID(ctx, id)
}

func (r *UserRepo) EliminarUsuario(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, id)
	if err != nil {
		if isFKViolation(err) {
			return false, domain.NewDomainError(
				"No se puede eliminar: el usuario tiene registros asociados "+
					"(asistencias, asignaciones de preceptor, horarios, etc.). "+
					"Desactivalo en su lugar si querés revocarle el acceso.", 409)
		}
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

func (r *UserRepo) ResetPassword(ctx context.Context, id string) (*string, error) {
	password := generatePassword()
	hash, err := hashPassword(password)
	if err != nil {
		return nil, err
	}
	tag, err := r.pool.Exec(ctx, `UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1`, id, hash)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return &password, nil
}

func (r *UserRepo) FindAuthByUsername(ctx context.Context, username string) (*domain.UsuarioAuth, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, email, full_name, role::text, is_active, password_hash
		 FROM users
		 WHERE lower(split_part(email, '@', 1)) = lower($1)`, username)
	var auth domain.UsuarioAuth
	var fullName, role string
	err := row.Scan(&auth.User.ID, &auth.User.Email, &fullName, &role, &auth.User.Activo, &auth.PasswordHash)
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	auth.User.Apellido, auth.User.Nombre = splitFullName(fullName)
	auth.User.Rol = domain.RolUsuario(role)
	return &auth, nil
}

// ── password helpers ─────────────────────────────────────────────────────────

func hashPassword(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	return string(b), err
}

// generatePassword produces an "abc.123"-style initial credential: three random
// lowercase letters, a dot, three random digits. (The previous Python backend
// used a random 10-char alphanumeric string; the AAM vision document specifies
// the abc.123 format, adopted here.)
func generatePassword() string {
	const letters = "abcdefghijkmnpqrstuvwxyz"
	const digits = "0123456789"
	buf := make([]byte, 7)
	rnd := make([]byte, 6)
	_, _ = rand.Read(rnd)
	for i := 0; i < 3; i++ {
		buf[i] = letters[int(rnd[i])%len(letters)]
	}
	buf[3] = '.'
	for i := 0; i < 3; i++ {
		buf[4+i] = digits[int(rnd[3+i])%len(digits)]
	}
	return string(buf)
}
