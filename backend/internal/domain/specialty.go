package domain

// Specialty catalogue. "Ciclo Básico" is the only one with IsBasicCycle=true —
// never chosen by hand, auto-assigned to 1ro-3ro courses.
type Specialty struct {
	ID           string
	Name         string
	IsBasicCycle bool
}

// SchoolSettings is the single configuration row: ceilings for the course
// creation dropdowns plus the thresholds used by the notification bell.
type SchoolSettings struct {
	MaxGradeYear                      int
	MaxDivision                       int
	ConsecutiveAbsencesAlertThreshold int
	PreceptorTempAssignmentAlertDays  int
	ScheduleExceptionAlertDays        int
}

// DefaultSchoolSettings is the safety-net used when the seeded row is missing,
// matching SchoolSettingsRepositoryImpl.get() in the Python backend.
func DefaultSchoolSettings() SchoolSettings {
	return SchoolSettings{
		MaxGradeYear:                      7,
		MaxDivision:                       4,
		ConsecutiveAbsencesAlertThreshold: 3,
		PreceptorTempAssignmentAlertDays:  2,
		ScheduleExceptionAlertDays:        2,
	}
}
