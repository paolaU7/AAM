package domain

import "time"

// EarlyDeparture is an anticipated exit: the preceptor records the time and
// reason, linked to that day's attendance record. No family notification in V1.
type EarlyDeparture struct {
	ID                 string
	AttendanceRecordID string
	DepartureTime      time.Time
	Reason             string
	RegisteredBy       string // user id
}
