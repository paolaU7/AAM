package domain

// Specialty catalogue. "Ciclo Básico" is the only one with IsBasicCycle=true —
// never chosen by hand, auto-assigned to 1ro-3ro courses.
type Specialty struct {
	ID           string
	Name         string
	IsBasicCycle bool
}

// SchoolSettings is the single school_settings row. `MaxGradeYear` (how many
// grade years exist) and `CurrentAcademicYear` are edited from Configuración →
// Cursos; the lunch window and the alert thresholds from Configuración →
// General. Per-year division counts live in year_structure, not here.
type SchoolSettings struct {
	MaxGradeYear        int
	CurrentAcademicYear int
	// Lunch window ("HH:MM"). Not a shift break, not enforced by any trigger —
	// just data the course-schedule builder uses to place the lunch period.
	LunchStart            string
	LunchStartFifthModule string
	LunchEnd              string

	ConsecutiveAbsencesAlertThreshold int
	PreceptorTempAssignmentAlertDays  int
	ScheduleExceptionAlertDays        int
}

// DefaultSchoolSettings is the safety-net used when the seeded row is missing.
func DefaultSchoolSettings() SchoolSettings {
	return SchoolSettings{
		MaxGradeYear:                      7,
		CurrentAcademicYear:               2026,
		LunchStart:                        "11:50",
		LunchStartFifthModule:             "12:50",
		LunchEnd:                          "13:10",
		ConsecutiveAbsencesAlertThreshold: 3,
		PreceptorTempAssignmentAlertDays:  2,
		ScheduleExceptionAlertDays:        2,
	}
}
