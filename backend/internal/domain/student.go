package domain

// EstadoRegularidad is the RITE-based regularity bucket a student falls into,
// derived from their attendance percentage.
type EstadoRegularidad string

const (
	RegularidadRegular   EstadoRegularidad = "regular"
	RegularidadIrregular EstadoRegularidad = "irregular"
	RegularidadEnRiesgo  EstadoRegularidad = "en_riesgo"
)

// Alumno is the student entity as consumed by the admin panel. The course
// dimensions (academic_year / grade_year / division) are exposed alongside the
// composed `Curso` label so the frontend table can filter/show them as
// independent columns without parsing the string.
type Alumno struct {
	ID                   string
	Nombre               string
	Apellido             string
	DNI                  string
	CursoID              string
	Curso                string
	Recursante           bool
	PorcentajeAsistencia float64
	AcademicYear         int
	GradeYear            int
	Division             int
	IsActive             bool
	WorkshopGroupID      *string
	Taller               *string // legible group label, when the student has a group
}

// NombreCompleto is the "Apellido, Nombre" display form.
func (a Alumno) NombreCompleto() string {
	return a.Apellido + ", " + a.Nombre
}

// EstadoRegularidad applies the fixed RITE thresholds: <65 en_riesgo,
// <75 irregular, otherwise regular. Ported 1:1 from the Python entity.
func (a Alumno) EstadoRegularidad() EstadoRegularidad {
	switch {
	case a.PorcentajeAsistencia < 65:
		return RegularidadEnRiesgo
	case a.PorcentajeAsistencia < 75:
		return RegularidadIrregular
	default:
		return RegularidadRegular
	}
}
