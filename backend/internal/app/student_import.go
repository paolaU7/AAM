package app

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// ImportRow is one parsed data row from the students Excel template. The HTTP
// adapter does the .xlsx parsing (excel.go) and hands rows here.
type ImportRow struct {
	Fila        int
	DNI         string
	Nombre      string
	Apellido    string
	GrupoTaller string
}

// ImportRowResult / ImportReport mirror student_import_usecases.py.
type ImportRowResult struct {
	Fila     int
	AlumnoID string
	Motivo   string
}

type ImportReport struct {
	CursoID    string
	TotalFilas int
	Creados    []ImportRowResult
	Errores    []ImportRowResult
}

// StudentImportService is ImportarAlumnosExcel. Each row is processed
// independently: a row error does not abort the rest of the file. A header
// problem (bad header, missing course) aborts the whole import via a
// *domain.DomainError return.
type StudentImportService struct {
	Students      domain.StudentRepo
	Courses       domain.CourseRepo
	WorkshopGroup domain.WorkshopGroupRepo
}

func (s StudentImportService) Import(ctx context.Context, academicYear, gradeYear, division int, rows []ImportRow) (*ImportReport, error) {
	course, err := s.Courses.ResolveCourse(ctx, academicYear, gradeYear, division)
	if err != nil {
		return nil, err
	}
	if course == nil {
		return nil, domain.NewDomainError(fmt.Sprintf(
			"No existe un curso cargado para año lectivo %d, año de cursada %d, división %d.",
			academicYear, gradeYear, division), 400)
	}

	groups, err := s.WorkshopGroup.GetByCourse(ctx, course.ID)
	if err != nil {
		return nil, err
	}
	byName := make(map[string]string, len(groups))
	for _, g := range groups {
		byName[strings.ToUpper(strings.TrimSpace(g.GroupLabel))] = g.ID
	}
	available := make([]string, 0, len(byName))
	for k := range byName {
		available = append(available, k)
	}
	sort.Strings(available)
	availableList := "ninguno"
	if len(available) > 0 {
		availableList = strings.Join(available, ", ")
	}

	report := &ImportReport{CursoID: course.ID, TotalFilas: len(rows)}

	for _, row := range rows {
		dni := strings.TrimSpace(row.DNI)
		nombre := strings.TrimSpace(row.Nombre)
		apellido := strings.TrimSpace(row.Apellido)
		grupoRaw := strings.TrimSpace(row.GrupoTaller)

		// Empty template placeholder row: ignored, counts as neither created
		// nor error.
		if dni == "" && nombre == "" && apellido == "" && grupoRaw == "" {
			report.TotalFilas--
			continue
		}

		alumno, rowErr := s.importOne(ctx, course.ID, byName, availableList, dni, nombre, apellido, grupoRaw)
		if rowErr != nil {
			report.Errores = append(report.Errores, ImportRowResult{Fila: row.Fila, Motivo: rowErr.Error()})
			continue
		}
		report.Creados = append(report.Creados, ImportRowResult{Fila: row.Fila, AlumnoID: alumno.ID})
	}

	return report, nil
}

func (s StudentImportService) importOne(
	ctx context.Context, courseID string, byName map[string]string, availableList string,
	dni, nombre, apellido, grupoRaw string,
) (*domain.Alumno, error) {
	if dni == "" || nombre == "" || apellido == "" {
		return nil, errors.New("Faltan datos obligatorios (DNI, nombre o apellido).")
	}

	var workshopGroupID *string
	if grupoRaw != "" {
		id, ok := byName[strings.ToUpper(grupoRaw)]
		if !ok {
			return nil, fmt.Errorf(
				"El grupo de taller '%s' no existe para este curso. Disponibles: %s.",
				grupoRaw, availableList)
		}
		workshopGroupID = &id
	}

	exists, err := s.Students.ExisteDNI(ctx, dni)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, errors.New("Ya existe un alumno registrado con ese DNI.")
	}

	return s.Students.CrearAlumnoManual(ctx, domain.CrearAlumnoParams{
		FirstName:       nombre,
		LastName:        apellido,
		NationalID:      dni,
		CourseID:        courseID,
		WorkshopGroupID: workshopGroupID,
	})
}
