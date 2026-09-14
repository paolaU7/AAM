package domain

import (
	"sort"
	"strings"
	"unicode"
)

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
	// ShortCode is a brief identifier (e.g. "M1r4t" for Matemática en 1ro y
	// 4to). Auto-generated at creation and recomputed whenever the subject's
	// applicability changes, as long as ShortCodeAuto stays true; editing it
	// by hand flips ShortCodeAuto to false and it stops being touched.
	ShortCode     string
	ShortCodeAuto bool
	// IsActive is the baja lógica flag: a subject can only be hard-deleted
	// once it's false, and only if nothing (course, teacher) still refers to
	// it.
	IsActive bool
}

// subjectShortCodeStopwords are short connector words skipped when deriving
// the letter prefix of a multi-word subject name (e.g. "Lengua y Literatura"
// -> "LL", not "LYL").
var subjectShortCodeStopwords = map[string]bool{
	"y": true, "e": true, "de": true, "del": true, "la": true, "el": true,
	"los": true, "las": true, "en": true, "a": true, "al": true,
}

// ComputeSubjectShortCode derives the auto-generated short code: the first
// letter of every "relevant" word in the name (skipping short connectors),
// uppercased, followed by one "<digit><ordinal-suffix-letter>" pair per
// distinct grade year the subject applies to, in ascending order — e.g.
// "Matemática" applicable to 1ro y 6to -> "M1r6t"; a single year -> "M6t";
// no applicability yet (just created) -> "M". Multi-word names use one
// letter per relevant word: "Lengua y Literatura" -> "LL".
func ComputeSubjectShortCode(name string, gradeYears []int) string {
	var letters strings.Builder
	for _, word := range strings.Fields(name) {
		if subjectShortCodeStopwords[strings.ToLower(word)] {
			continue
		}
		runes := []rune(word)
		if len(runes) == 0 {
			continue
		}
		letters.WriteRune(unicode.ToUpper(runes[0]))
	}

	distinct := make(map[int]bool, len(gradeYears))
	for _, y := range gradeYears {
		distinct[y] = true
	}
	years := make([]int, 0, len(distinct))
	for y := range distinct {
		years = append(years, y)
	}
	sort.Ints(years)

	var code strings.Builder
	code.WriteString(letters.String())
	for _, y := range years {
		ordinal := GradeYearOrdinal(y) // "1ro", "2do", "4to"...
		if len(ordinal) >= 2 {
			code.WriteString(ordinal[:2]) // digit + first suffix letter: "1r", "4t"...
		}
	}
	return code.String()
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

// SubjectWithApplicability bundles a subject with its subject_applicability
// rows (specialty name included) — the shape the Materias screen needs to
// filter the catalogue by año/especialidad without an extra request per row.
type SubjectWithApplicability struct {
	Subject
	Applicability []SubjectApplicability
}

// Teacher is a reference record for the schedule. No login.
type Teacher struct {
	ID           string
	FullName     string
	Email        *string
	Phone        *string
	Status       string
	StatusReason *string
	ReturnDate   *string
}

const (
	TeacherStatusActive       = "active"
	TeacherStatusInactive     = "inactive"
	TeacherStatusMedicalLeave = "medical_leave"
	TeacherStatusVacation     = "vacation"
)

func ValidTeacherStatus(s string) bool {
	switch s {
	case TeacherStatusActive, TeacherStatusInactive, TeacherStatusMedicalLeave, TeacherStatusVacation:
		return true
	default:
		return false
	}
}

// SubjectTeacherAssignment is which subject a teacher teaches, in ONE course.
type SubjectTeacherAssignment struct {
	CourseID    string
	SubjectID   string
	SubjectName string
	SubjectType string
	// SubjectShortCode mirrors Subject.ShortCode — carried here so the
	// Profesores screen can show a compact "materias asignadas" column
	// (e.g. "M1r4t") without a second lookup against the subjects catalogue.
	SubjectShortCode string
	TeacherID        string
	TeacherName      string
	TeacherEmail     *string
	TeacherPhone     *string
	CourseName       *string
}

// TeacherWithAssignments bundles a teacher with every course_subject_teachers
// row it appears in — the shape the Profesores screen needs to show a
// "materias asignadas" column without a request per row (same idea as
// SubjectWithApplicability for the Materias screen).
type TeacherWithAssignments struct {
	Teacher
	Assignments []SubjectTeacherAssignment
}
