package app

import (
	"context"

	"github.com/oklog/ulid/v2"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// DeviceSyncService is the (minimal, new) ingestion path for ESP32 readers:
// one reading over HTTP when online, or a batch replayed from the LittleFS
// offline buffer. Deduplication is by ULID in Postgres
// (INSERT ... ON CONFLICT (id) DO NOTHING).
type DeviceSyncService struct {
	Sync domain.DeviceSyncPort
}

// validateULID rejects a device-supplied id that is not a well-formed ULID,
// using oklog/ulid for parsing (the requirement's "librería equivalente").
func validateULID(id string) error {
	if _, err := ulid.ParseStrict(id); err != nil {
		return domain.Errorf("ULID inválido: %q.", id)
	}
	return nil
}

// IngestOne handles POST /device/attendance.
func (s DeviceSyncService) IngestOne(ctx context.Context, in domain.DeviceAttendanceInput) (stored bool, err error) {
	if err := validateULID(in.ID); err != nil {
		return false, err
	}
	if in.TagUID == "" {
		return false, domain.NewDomainError("Falta el UID de la pulsera.", 400)
	}
	return s.Sync.IngestOne(ctx, in)
}

// IngestBatch handles POST /device/sync. Malformed rows are reported per-ULID
// and do not abort the batch.
func (s DeviceSyncService) IngestBatch(ctx context.Context, in []domain.DeviceAttendanceInput) (domain.SyncResult, error) {
	valid := make([]domain.DeviceAttendanceInput, 0, len(in))
	res := domain.SyncResult{}
	for _, rec := range in {
		if err := validateULID(rec.ID); err != nil {
			res.Rejected = append(res.Rejected, domain.SyncRejection{ID: rec.ID, Reason: err.Error()})
			continue
		}
		if rec.TagUID == "" {
			res.Rejected = append(res.Rejected, domain.SyncRejection{ID: rec.ID, Reason: "Falta el UID de la pulsera."})
			continue
		}
		valid = append(valid, rec)
	}
	if len(valid) == 0 {
		return res, nil
	}
	stored, err := s.Sync.IngestBatch(ctx, valid)
	if err != nil {
		return res, err
	}
	stored.Rejected = append(stored.Rejected, res.Rejected...)
	return stored, nil
}
