package domain

// CoursePreceptor is the PERMANENT preceptor in charge of a course, per shift,
// for the whole school year. A course can have a different preceptor per shift.
type CoursePreceptor struct {
	CourseID      string
	Shift         string
	PreceptorID   string
	PreceptorName string
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
