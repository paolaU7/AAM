package domain

// CoursePreceptor is a PERMANENT preceptor in charge of a course for a
// specific shift+day combination. Multiple preceptors can cover different
// days of the week within the same course+shift.
type CoursePreceptor struct {
	ID            string
	CourseID      string
	Shift         string
	PreceptorID   string
	PreceptorName string
	DayOfWeek     int // ISO 1..7
}

// CoursePreceptorTempAssignment is a TEMPORARY replacement (e.g. leave), with a
// date range — at most one calendar month, enforced both here and by a DB CHECK.
type CoursePreceptorTempAssignment struct {
	ID            string
	CourseID      string
	Shift         string
	PreceptorID   string
	PreceptorName string
	StartDate     string // YYYY-MM-DD
	EndDate       string // YYYY-MM-DD
	Reason        *string
}
