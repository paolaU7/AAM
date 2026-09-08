package app

import (
	"context"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// ClassPeriodService covers class_period_usecases.py.
type ClassPeriodService struct {
	Repo          domain.ClassPeriodRepo
	WorkshopGroup domain.WorkshopGroupRepo
}

func (s ClassPeriodService) ByCourse(ctx context.Context, courseID string) ([]domain.ClassPeriod, error) {
	return s.Repo.GetByCourse(ctx, courseID)
}

func (s ClassPeriodService) Create(ctx context.Context, p domain.CreateClassPeriodParams) (domain.ClassPeriod, error) {
	if err := domain.ValidateDayOfWeek(p.DayOfWeek); err != nil {
		return domain.ClassPeriod{}, err
	}
	if err := domain.ValidateTimeOrder(p.StartTime, p.EndTime); err != nil {
		return domain.ClassPeriod{}, err
	}
	if p.PeriodType == domain.PeriodClass && (p.SubjectID == nil || *p.SubjectID == "") {
		return domain.ClassPeriod{}, domain.NewDomainError("Un período de clase necesita una materia.", 400)
	}
	if p.PeriodType == domain.PeriodRecess || p.PeriodType == domain.PeriodLunch {
		if (p.SubjectID != nil && *p.SubjectID != "") || (p.TeacherID != nil && *p.TeacherID != "") {
			return domain.ClassPeriod{}, domain.NewDomainError("Recreo y almuerzo no llevan materia ni profesor.", 400)
		}
	}

	if p.WorkshopGroupID != nil && *p.WorkshopGroupID != "" {
		groups, err := s.WorkshopGroup.GetByCourse(ctx, p.CourseID)
		if err != nil {
			return domain.ClassPeriod{}, err
		}
		ok := false
		for _, g := range groups {
			if g.ID == *p.WorkshopGroupID {
				ok = true
				break
			}
		}
		if !ok {
			return domain.ClassPeriod{}, domain.NewDomainError("El grupo de taller no pertenece a este curso.", 400)
		}
	}

	return s.Repo.Create(ctx, p)
}

func (s ClassPeriodService) Delete(ctx context.Context, id string) (bool, error) {
	return s.Repo.Delete(ctx, id)
}
