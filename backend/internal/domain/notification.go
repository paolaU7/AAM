package domain

// Notification types shown by the header bell.
const (
	NotifPreceptorTempAssignment = "preceptor_temp_assignment"
	NotifScheduleException       = "schedule_exception"
	NotifConsecutiveAbsences     = "consecutive_absences"
)

// Notification is an alert computed on the fly for the header bell — never
// persisted, recomputed every time the dropdown opens. Message is display-ready
// text; the frontend only picks an icon/colour from Type.
type Notification struct {
	Type    string
	Message string
}
