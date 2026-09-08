package app

import (
	"context"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// CourseService covers GetCourses / GetCourseById / CreateCourse / UpdateCourse
// (course_usecases.py).
type CourseService struct {
	Repo      domain.CourseRepo
	Specialty domain.SpecialtyRepo
}

func (s CourseService) List(ctx context.Context) ([]domain.Course, error) {
	return s.Repo.GetCourses(ctx)
}

func (s CourseService) Get(ctx context.Context, id string) (*domain.Course, error) {
	return s.Repo.GetCourseByID(ctx, id)
}

func (s CourseService) validateSpecialty(ctx context.Context, gradeYear int, specialtyID string) error {
	if specialtyID == "" {
		return domain.NewDomainError("Seleccioná la especialidad.", 400)
	}
	sp, err := s.Specialty.GetByID(ctx, specialtyID)
	if err != nil {
		return err
	}
	return domain.ValidateBasicCycleSpecialty(sp, gradeYear, false)
}

func (s CourseService) Create(ctx context.Context, academicYear, gradeYear, division int, specialtyID string) (*domain.Course, error) {
	if err := domain.ValidateDimensions(gradeYear, division); err != nil {
		return nil, err
	}
	if err := s.validateSpecialty(ctx, gradeYear, specialtyID); err != nil {
		return nil, err
	}
	existing, err := s.Repo.ResolveCourse(ctx, academicYear, gradeYear, division)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, domain.NewDomainError("Ya existe un curso con ese año lectivo, año de cursada y división.", 409)
	}
	return s.Repo.CreateCourse(ctx, academicYear, gradeYear, division, specialtyID)
}

func (s CourseService) Update(ctx context.Context, id string, academicYear, gradeYear, division int, specialtyID string) (*domain.Course, error) {
	if err := domain.ValidateDimensions(gradeYear, division); err != nil {
		return nil, err
	}
	if err := s.validateSpecialty(ctx, gradeYear, specialtyID); err != nil {
		return nil, err
	}
	existing, err := s.Repo.ResolveCourse(ctx, academicYear, gradeYear, division)
	if err != nil {
		return nil, err
	}
	if existing != nil && existing.ID != id {
		return nil, domain.NewDomainError("Ya existe un curso con ese año lectivo, año de cursada y división.", 409)
	}
	updated, err := s.Repo.UpdateCourse(ctx, id, academicYear, gradeYear, division, specialtyID)
	if err != nil {
		return nil, err
	}
	if updated == nil {
		return nil, domain.NewDomainError("El curso no existe.", 404)
	}
	return updated, nil
}
