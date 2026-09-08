package postgres

import (
	"errors"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// mapDBError turns a Postgres error into a user-facing *domain.DomainError,
// best-effort extracting the real message (e.g. a trigger's RAISE EXCEPTION),
// mirroring _extract_db_error_message in the Python backend. Non-Postgres
// errors pass through unchanged.
func mapDBError(err error, fallback string) error {
	if err == nil {
		return nil
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		msg := strings.TrimSpace(pgErr.Message)
		if i := strings.IndexByte(msg, '\n'); i >= 0 {
			msg = msg[:i]
		}
		if msg == "" {
			msg = fallback
		}
		status := 400
		if pgErr.Code == "23505" { // unique_violation
			status = 409
		}
		return domain.NewDomainError(msg, status)
	}
	return err
}

// isFKViolation reports whether err is a foreign-key violation (23503) — used
// to detect "user still has associated records" on delete.
func isFKViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23503"
}
