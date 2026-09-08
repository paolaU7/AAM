package app

import (
	"context"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// PreceptorService covers preceptor_assignment_usecases.py.
type PreceptorService struct {
	Permanent domain.CoursePreceptorRepo
	Temp      domain.CoursePreceptorTempAssignmentRepo
}

func (s PreceptorService) ByCourse(ctx context.Context, courseID string) ([]domain.CoursePreceptor, error) {
	return s.Permanent.GetByCourse(ctx, courseID)
}

func (s PreceptorService) Assign(ctx context.Context, courseID, shift, preceptorID string) (domain.CoursePreceptor, error) {
	if preceptorID == "" {
		return domain.CoursePreceptor{}, domain.NewDomainError("El preceptor es obligatorio.", 400)
	}
	return s.Permanent.Assign(ctx, courseID, shift, preceptorID)
}

func (s PreceptorService) Remove(ctx context.Context, courseID, shift string) (bool, error) {
	return s.Permanent.Remove(ctx, courseID, shift)
}

func (s PreceptorService) TempByCourse(ctx context.Context, courseID string) ([]domain.CoursePreceptorTempAssignment, error) {
	return s.Temp.GetByCourse(ctx, courseID)
}

// CreateTemp mirrors CreateCoursePreceptorTempAssignment: max 1 calendar month.
func (s PreceptorService) CreateTemp(ctx context.Context, p domain.CreateTempAssignmentParams) (domain.CoursePreceptorTempAssignment, error) {
	if p.PreceptorID == "" {
		return domain.CoursePreceptorTempAssignment{}, domain.NewDomainError("El preceptor es obligatorio.", 400)
	}
	if p.CreatedBy == "" {
		return domain.CoursePreceptorTempAssignment{}, domain.NewDomainError("Falta indicar quién asigna el reemplazo.", 400)
	}
	if p.EndDate < p.StartDate {
		return domain.CoursePreceptorTempAssignment{}, domain.NewDomainError("La fecha de fin no puede ser anterior a la de inicio.", 400)
	}
	limit, err := domain.AddOneCalendarMonth(p.StartDate)
	if err != nil {
		return domain.CoursePreceptorTempAssignment{}, err
	}
	if p.EndDate > limit {
		return domain.CoursePreceptorTempAssignment{}, domain.Errorf(
			"El reemplazo temporal no puede superar 1 mes (hasta %s como máximo).", limit)
	}
	return s.Temp.Create(ctx, p)
}

func (s PreceptorService) DeleteTemp(ctx context.Context, id string) (bool, error) {
	return s.Temp.Delete(ctx, id)
}
