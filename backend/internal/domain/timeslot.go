package domain

// Shift and activity-type vocabularies (Postgres enums shift_type / activity_type).
const (
	ShiftMorning   = "morning"
	ShiftAfternoon = "afternoon"
	ShiftEvening   = "evening"

	ActivityMainShift  = "main_shift"
	ActivityWorkshop   = "workshop"
	ActivityAfterShift = "after_shift"

	PeriodClass  = "class"
	PeriodRecess = "recess"
	PeriodLunch  = "lunch"
)

// TimeSlot is a recurring weekly slot for a course OR a workshop group —
// exactly one of CourseID / WorkshopGroupID is set. This is what opens/closes
// the attendance window for a shift.
type TimeSlot struct {
	ID                   string
	Shift                string
	ActivityType         string
	DayOfWeek            int    // ISO 1..7
	StartTime            string // HH:MM:SS
	EndTime              string // HH:MM:SS
	LateToleranceMinutes int
	CourseID             *string
	WorkshopGroupID      *string
}

// ClassPeriod is a slot in the DETAILED day-by-day schedule (a lesson with
// subject+teacher, a recess or lunch). Distinct from TimeSlot: it is only for
// building/showing the full grid, it does not trigger per-period attendance.
type ClassPeriod struct {
	ID              string
	CourseID        string
	WorkshopGroupID *string
	DayOfWeek       int
	Shift           string
	PeriodOrder     int
	PeriodType      string
	StartTime       string
	EndTime         string
	IsFifthModule   bool
	SubjectID       *string
	SubjectName     *string
	TeacherID       *string
	TeacherName     *string
}
