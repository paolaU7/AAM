package app

import (
	"context"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// TimeSlotService covers time_slot_usecases.py.
type TimeSlotService struct {
	Repo domain.TimeSlotRepo
}

func (s TimeSlotService) ByCourse(ctx context.Context, courseID string) ([]domain.TimeSlot, error) {
	return s.Repo.GetByCourse(ctx, courseID)
}

func (s TimeSlotService) ByWorkshopGroup(ctx context.Context, workshopGroupID string) ([]domain.TimeSlot, error) {
	return s.Repo.GetByWorkshopGroup(ctx, workshopGroupID)
}

// CreateForCourse is CreateCourseTimeSlot — a MAIN-SHIFT slot (curricular or
// after-shift), not a workshop group's.
func (s TimeSlotService) CreateForCourse(ctx context.Context, courseID, shift, activityType string, dayOfWeek int, startTime, endTime string, lateTolerance int) (domain.TimeSlot, error) {
	if activityType != domain.ActivityMainShift && activityType != domain.ActivityAfterShift {
		return domain.TimeSlot{}, domain.NewDomainError("activity_type debe ser 'main_shift' o 'after_shift' para el turno principal.", 400)
	}
	if err := domain.ValidateDayOfWeek(dayOfWeek); err != nil {
		return domain.TimeSlot{}, err
	}
	if err := domain.ValidateTimeOrder(startTime, endTime); err != nil {
		return domain.TimeSlot{}, err
	}
	cid := courseID
	return s.Repo.Create(ctx, domain.CreateTimeSlotParams{
		CourseID:             &cid,
		Shift:                shift,
		ActivityType:         activityType,
		DayOfWeek:            dayOfWeek,
		StartTime:            startTime,
		EndTime:              endTime,
		LateToleranceMinutes: lateTolerance,
	})
}

func (s TimeSlotService) Delete(ctx context.Context, id string) (bool, error) {
	return s.Repo.Delete(ctx, id)
}
