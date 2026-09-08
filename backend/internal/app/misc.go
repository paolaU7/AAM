package app

import (
	"context"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// SpecialtyService covers specialty_usecases.py.
type SpecialtyService struct {
	Repo     domain.SpecialtyRepo
	Settings domain.SchoolSettingsRepo
}

func (s SpecialtyService) List(ctx context.Context) ([]domain.Specialty, error) {
	return s.Repo.GetAll(ctx)
}

func (s SpecialtyService) SchoolSettings(ctx context.Context) (domain.SchoolSettings, error) {
	return s.Settings.Get(ctx)
}

// WorkshopGroupService is the read-only workshop group access used by the
// workshop-groups routes.
type WorkshopGroupService struct {
	Repo domain.WorkshopGroupRepo
}

func (s WorkshopGroupService) List(ctx context.Context) ([]domain.WorkshopGroup, error) {
	return s.Repo.GetAll(ctx)
}

func (s WorkshopGroupService) ByCourse(ctx context.Context, courseID string) ([]domain.WorkshopGroup, error) {
	return s.Repo.GetByCourse(ctx, courseID)
}

// NotificationService covers notification_usecases.py: it reads the thresholds
// from school settings, then asks the repo for the on-the-fly alerts.
type NotificationService struct {
	Repo     domain.NotificationRepo
	Settings domain.SchoolSettingsRepo
}

func (s NotificationService) Alerts(ctx context.Context) ([]domain.Notification, error) {
	settings, err := s.Settings.Get(ctx)
	if err != nil {
		return nil, err
	}
	return s.Repo.GetAlerts(ctx,
		settings.PreceptorTempAssignmentAlertDays,
		settings.ScheduleExceptionAlertDays,
		settings.ConsecutiveAbsencesAlertThreshold,
	)
}
