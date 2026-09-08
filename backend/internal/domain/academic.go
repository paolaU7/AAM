package domain

// Subject types. Fixed from creation — the same subject taught in both contexts
// is two different rows.
const (
	SubjectCurricular = "curricular"
	SubjectWorkshop   = "workshop"
)

// Subject is the global, reusable subject catalogue entry.
type Subject struct {
	ID          string
	Name        string
	SubjectType string
}

// SubjectApplicability says in which grade year (+ specialty, for 4th year and
// up) a subject may be taught. A subject can have several of these.
type SubjectApplicability struct {
	ID            string
	SubjectID     string
	GradeYear     int
	SpecialtyID   string
	SpecialtyName string
}

// Teacher is a reference record for the schedule. No login.
type Teacher struct {
	ID       string
	FullName string
	Email    *string
	Phone    *string
}

// SubjectTeacherAssignment is which subject a teacher teaches, in ONE course.
type SubjectTeacherAssignment struct {
	CourseID     string
	SubjectID    string
	SubjectName  string
	SubjectType  string
	TeacherID    string
	TeacherName  string
	TeacherEmail *string
	TeacherPhone *string
	CourseName   *string
}
