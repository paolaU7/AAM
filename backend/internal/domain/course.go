package domain

// Course is the combination of three independent numeric dimensions
// (academic_year, grade_year, division). specialty_id is ALWAYS required
// (1ro-3ro -> "Ciclo Básico", assigned only by the UI). SpecialtyName / Name /
// TotalStudents are display helpers computed by the repository, not columns.
type Course struct {
	ID            string
	AcademicYear  int
	GradeYear     int
	Division      int
	SpecialtyID   string
	SpecialtyName string
	TotalStudents int
	Name          string
}
