package domain

import "time"

// Attendance sources and statuses. `non_computable_absence` does NOT affect the
// RITE attendance rate; `absent_with_presence` is grouped with `absent` for the
// daily summary.
const (
	SourceNFC    = "nfc"
	SourceQR     = "qr"
	SourceManual = "manual"

	StatusPresent              = "present"
	StatusLate                 = "late"
	StatusAbsent               = "absent"
	StatusAbsentWithPresence   = "absent_with_presence"
	StatusNonComputableAbsence = "non_computable_absence"
)

// RegistroAsistencia is one attendance record. `ID` is the 26-char ULID
// generated on the ESP32 device; for manual entries it is generated server-side.
type RegistroAsistencia struct {
	ID              string
	StudentID       string
	StudentName     string
	CourseID        string
	EntryTimestamp  time.Time
	Source          string
	Status          string
	DepartureTime   *time.Time
	DepartureReason *string
}

func (r RegistroAsistencia) HasEarlyDeparture() bool { return r.DepartureTime != nil }

// ResumenAsistencia is the aggregated daily (or per-shift) attendance picture.
type ResumenAsistencia struct {
	Date                 string // YYYY-MM-DD
	Present              int
	Absent               int
	Late                 int
	NonComputableAbsence int
	EarlyDepartures      int
	Total                int
}

// ValidAttendanceStatus reports whether s is one a preceptor may set on a
// manual check-in / status change.
func ValidAttendanceStatus(s string) bool {
	switch s {
	case StatusPresent, StatusLate, StatusAbsent, StatusAbsentWithPresence, StatusNonComputableAbsence:
		return true
	default:
		return false
	}
}
