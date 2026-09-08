package app

import (
	"context"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// StudentService covers student_usecases.py (GetAlumnos, GetAlumnoPorId,
// ActualizarAlumno, ToggleAlumnoActive, CrearAlumnoManual).
type StudentService struct {
	Repo          domain.StudentRepo
	Courses       domain.CourseRepo
	WorkshopGroup domain.WorkshopGroupRepo
}

func (s StudentService) List(ctx context.Context, includeInactive bool) ([]domain.Alumno, error) {
	return s.Repo.GetAlumnos(ctx, includeInactive)
}

func (s StudentService) Get(ctx context.Context, id string) (*domain.Alumno, error) {
	return s.Repo.GetAlumnoPorID(ctx, id)
}

func (s StudentService) Update(ctx context.Context, id string, a domain.Alumno) (*domain.Alumno, error) {
	return s.Repo.ActualizarAlumno(ctx, id, a)
}

func (s StudentService) ToggleActive(ctx context.Context, id string) (*domain.Alumno, error) {
	return s.Repo.ToggleActive(ctx, id)
}

// workshopGroupBelongsToCourse checks the group (when given) belongs to courseID.
func (s StudentService) workshopGroupBelongsToCourse(ctx context.Context, courseID string, workshopGroupID *string) error {
	if workshopGroupID == nil || *workshopGroupID == "" {
		return nil
	}
	groups, err := s.WorkshopGroup.GetByCourse(ctx, courseID)
	if err != nil {
		return err
	}
	for _, g := range groups {
		if g.ID == *workshopGroupID {
			return nil
		}
	}
	return domain.NewDomainError("El grupo de taller no pertenece al curso seleccionado.", 400)
}

// CreateManual mirrors CrearAlumnoManual: course already resolved by the
// frontend cascade, sent as course_id.
func (s StudentService) CreateManual(ctx context.Context, p domain.CrearAlumnoParams) (*domain.Alumno, error) {
	p.FirstName = strings.TrimSpace(p.FirstName)
	p.LastName = strings.TrimSpace(p.LastName)
	p.NationalID = strings.TrimSpace(p.NationalID)

	if p.FirstName == "" || p.LastName == "" || p.NationalID == "" {
		return nil, domain.NewDomainError("Nombre, apellido y DNI son obligatorios.", 400)
	}

	if p.CourseID == "" {
		return nil, domain.NewDomainError("El curso seleccionado no existe.", 400)
	}
	course, err := s.Courses.GetCourseByID(ctx, p.CourseID)
	if err != nil {
		return nil, err
	}
	if course == nil {
		return nil, domain.NewDomainError("El curso seleccionado no existe.", 400)
	}

	if err := s.workshopGroupBelongsToCourse(ctx, p.CourseID, p.WorkshopGroupID); err != nil {
		return nil, err
	}

	exists, err := s.Repo.ExisteDNI(ctx, p.NationalID)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, domain.NewDomainError("Ya existe un alumno registrado con ese DNI.", 409)
	}

	return s.Repo.CrearAlumnoManual(ctx, p)
}
