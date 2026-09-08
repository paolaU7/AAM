package app

import (
	"context"
	"testing"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

type fakeTempRepo struct {
	created *domain.CreateTempAssignmentParams
}

func (f *fakeTempRepo) GetByCourse(context.Context, string) ([]domain.CoursePreceptorTempAssignment, error) {
	return nil, nil
}
func (f *fakeTempRepo) Create(_ context.Context, p domain.CreateTempAssignmentParams) (domain.CoursePreceptorTempAssignment, error) {
	f.created = &p
	return domain.CoursePreceptorTempAssignment{ID: "t1", CourseID: p.CourseID, Shift: p.Shift}, nil
}
func (f *fakeTempRepo) Delete(context.Context, string) (bool, error) { return true, nil }

func TestCreateTemp_MonthLimit(t *testing.T) {
	svc := PreceptorService{Temp: &fakeTempRepo{}}
	base := domain.CreateTempAssignmentParams{
		CourseID: "c1", Shift: domain.ShiftMorning, PreceptorID: "p1", CreatedBy: "u1",
		StartDate: "2026-03-01",
	}

	// within a calendar month -> ok
	ok := base
	ok.EndDate = "2026-03-31"
	if _, err := svc.CreateTemp(context.Background(), ok); err != nil {
		t.Errorf("expected 31-day replacement to be allowed, got %v", err)
	}

	// beyond one calendar month -> rejected
	tooLong := base
	tooLong.EndDate = "2026-04-05"
	if _, err := svc.CreateTemp(context.Background(), tooLong); err == nil {
		t.Error("expected replacement longer than 1 month to be rejected")
	}

	// end before start -> rejected
	backwards := base
	backwards.EndDate = "2026-02-20"
	if _, err := svc.CreateTemp(context.Background(), backwards); err == nil {
		t.Error("expected end-before-start to be rejected")
	}

	// missing created_by -> rejected
	noAuthor := base
	noAuthor.EndDate = "2026-03-10"
	noAuthor.CreatedBy = ""
	if _, err := svc.CreateTemp(context.Background(), noAuthor); err == nil {
		t.Error("expected missing created_by to be rejected")
	}
}
