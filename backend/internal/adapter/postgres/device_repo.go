package postgres

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/oklog/ulid/v2"
	"github.com/paolaU7/AAM/backend/internal/domain"
	"golang.org/x/crypto/bcrypt"
)

// DeviceRepo resolves ESP32 reader API keys against `devices.api_key_hash`
// (bcrypt). Keys are rotated manually in V1.
type DeviceRepo struct{ pool *pgxpool.Pool }

func NewDeviceRepo(pool *pgxpool.Pool) *DeviceRepo { return &DeviceRepo{pool} }

func (r *DeviceRepo) FindByAPIKey(ctx context.Context, apiKey string) (*domain.Device, error) {
	if apiKey == "" {
		return nil, nil
	}
	rows, err := r.pool.Query(ctx,
		`SELECT id, device_name, location, api_key_hash FROM devices WHERE is_active`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var d domain.Device
		var hash string
		if err := rows.Scan(&d.ID, &d.Name, &d.Location, &hash); err != nil {
			return nil, err
		}
		if bcrypt.CompareHashAndPassword([]byte(hash), []byte(apiKey)) == nil {
			d.IsActive = true
			return &d, rows.Err()
		}
	}
	return nil, rows.Err()
}

func (r *DeviceRepo) TouchLastSeen(ctx context.Context, deviceID string) error {
	_, err := r.pool.Exec(ctx, `UPDATE devices SET last_seen_at = now() WHERE id = $1`, deviceID)
	return err
}

// ── Device sync (attendance ingestion) ───────────────────────────────────────

// DeviceSyncRepo implements domain.DeviceSyncPort. It resolves the NFC bracelet
// UID to a student, then inserts the reading with
// INSERT ... ON CONFLICT (id) DO NOTHING (dedup by ULID). This is V1
// scaffolding: it assumes an `nfc_bracelets(tag_uid, student_id, is_active)`
// link table and defaults status to 'present'.
type DeviceSyncRepo struct{ pool *pgxpool.Pool }

func NewDeviceSyncRepo(pool *pgxpool.Pool) *DeviceSyncRepo { return &DeviceSyncRepo{pool} }

func (r *DeviceSyncRepo) IngestOne(ctx context.Context, in domain.DeviceAttendanceInput) (bool, error) {
	studentID, courseID, err := r.resolveBracelet(ctx, in.TagUID)
	if err != nil {
		return false, err
	}
	return r.insert(ctx, in, studentID, courseID)
}

func (r *DeviceSyncRepo) IngestBatch(ctx context.Context, in []domain.DeviceAttendanceInput) (domain.SyncResult, error) {
	var res domain.SyncResult
	for _, rec := range in {
		studentID, courseID, err := r.resolveBracelet(ctx, rec.TagUID)
		if err != nil {
			var de *domain.DomainError
			if errors.As(err, &de) {
				res.Rejected = append(res.Rejected, domain.SyncRejection{ID: rec.ID, Reason: de.Message})
				continue
			}
			return res, err
		}
		stored, err := r.insert(ctx, rec, studentID, courseID)
		if err != nil {
			return res, err
		}
		if stored {
			res.Accepted = append(res.Accepted, rec.ID)
		} else {
			res.Duplicated = append(res.Duplicated, rec.ID)
		}
	}
	return res, nil
}

func (r *DeviceSyncRepo) insert(ctx context.Context, in domain.DeviceAttendanceInput, studentID, courseID string) (bool, error) {
	// Guard: id must be a valid ULID (the app layer also checks this).
	if _, err := ulid.ParseStrict(in.ID); err != nil {
		return false, domain.Errorf("ULID inválido: %q.", in.ID)
	}
	tag, err := r.pool.Exec(ctx, `
		INSERT INTO attendance_records
		    (id, student_id, course_id, device_id, source, status, entry_timestamp)
		VALUES ($1, $2, $3, $4, 'nfc'::attendance_source, 'present'::attendance_status, $5)
		ON CONFLICT (id) DO NOTHING`,
		in.ID, studentID, courseID, nullIfEmpty(in.DeviceID), in.EntryTimestamp)
	if err != nil {
		return false, mapDBError(err, "No se pudo guardar el registro de asistencia.")
	}
	return tag.RowsAffected() > 0, nil
}

// resolveBracelet maps an NFC UID to (student_id, course_id). Returns a
// *domain.DomainError (422) when the bracelet is unknown, and a plain error
// when the link table is not present yet.
func (r *DeviceSyncRepo) resolveBracelet(ctx context.Context, tagUID string) (studentID, courseID string, err error) {
	row := r.pool.QueryRow(ctx, `
		SELECT s.id, s.course_id
		FROM nfc_bracelets b
		JOIN students s ON s.id = b.student_id
		WHERE lower(b.tag_uid) = lower($1) AND COALESCE(b.is_active, TRUE) AND s.is_active`, tagUID)
	err = row.Scan(&studentID, &courseID)
	switch {
	case noRows(err):
		return "", "", domain.NewDomainError("Pulsera no reconocida o alumno inactivo.", 422)
	case err != nil:
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "42P01" { // undefined_table
			return "", "", domain.NewDomainError(
				"El vínculo pulsera↔alumno no está configurado todavía (falta la tabla nfc_bracelets).", 501)
		}
		return "", "", err
	default:
		return studentID, courseID, nil
	}
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}
