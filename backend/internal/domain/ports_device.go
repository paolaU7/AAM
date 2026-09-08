package domain

import (
	"context"
	"time"
)

// Device is a registered NFC reader (ESP32 + PN532). It authenticates against
// the backend with a static API key (manual rotation in V1).
type Device struct {
	ID       string
	Name     string
	Location *string
	IsActive bool
}

// DeviceRepo persists `devices` and resolves API keys.
type DeviceRepo interface {
	// FindByAPIKey returns the active device whose api_key_hash matches the
	// presented key, or nil when none matches.
	FindByAPIKey(ctx context.Context, apiKey string) (*Device, error)
	// TouchLastSeen records that the device just contacted the backend.
	TouchLastSeen(ctx context.Context, deviceID string) error
}

// DeviceAttendanceInput is one buffered reading pushed by a reader. The ID is
// the ULID generated on the device; TagUID identifies the NFC bracelet.
type DeviceAttendanceInput struct {
	ID             string
	TagUID         string
	DeviceID       string
	EntryTimestamp time.Time
}

// SyncResult reports, per submitted ULID, whether the record was newly stored
// or already present (deduplicated).
type SyncResult struct {
	Accepted   []string // ULIDs stored now
	Duplicated []string // ULIDs already present (ON CONFLICT DO NOTHING)
	Rejected   []SyncRejection
}

type SyncRejection struct {
	ID     string
	Reason string
}

// DeviceSyncPort ingests device readings. Deduplication is by ULID
// (INSERT ... ON CONFLICT (id) DO NOTHING).
type DeviceSyncPort interface {
	IngestOne(ctx context.Context, in DeviceAttendanceInput) (stored bool, err error)
	IngestBatch(ctx context.Context, in []DeviceAttendanceInput) (SyncResult, error)
}

// ── Recursante schedule-overlap detection ────────────────────────────────────

// OverlapDetector decides whether a repeating student's absence from the
// current shift must be marked as a NON-COMPUTABLE absence because the shift
// overlaps a subject they are re-taking from a previous year. Non-computable
// absences never affect the RITE rate. In V1 the preceptor also handles this
// manually; this port is the automatic half.
type OverlapDetector interface {
	// IsNonComputable reports whether, on the given date, studentID has a
	// schedule overlap that makes their absence from courseID/shift
	// non-computable.
	IsNonComputable(ctx context.Context, studentID, courseID, shift, date string) (bool, error)
}
