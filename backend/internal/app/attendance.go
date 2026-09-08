package app

import (
	"context"
	"strings"
	"time"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// AttendanceService covers attendance_usecases.py.
type AttendanceService struct {
	Repo domain.AttendanceRepo
	// Overlap is the automatic non-computable-absence detector for repeating
	// students. Optional in V1 (may be a no-op); the preceptor also handles
	// this manually.
	Overlap domain.OverlapDetector
}

func (s AttendanceService) ByCourseAndDate(ctx context.Context, courseID, date string) ([]domain.RegistroAsistencia, error) {
	return s.Repo.GetByCourseAndDate(ctx, courseID, date)
}

// AutoNonComputable is the hook for the automatic recursante rule: it asks the
// OverlapDetector whether a repeating student's absence from this shift should
// be non-computable (schedule overlap with a re-taken subject). V1's detector
// is a stub that always returns false — the preceptor marks these manually via
// MarkNonComputable — but the seam is wired so the automatic path can be
// enabled without touching the HTTP or domain layers.
func (s AttendanceService) AutoNonComputable(ctx context.Context, studentID, courseID, shift, date string) (bool, error) {
	if s.Overlap == nil {
		return false, nil
	}
	return s.Overlap.IsNonComputable(ctx, studentID, courseID, shift, date)
}

func (s AttendanceService) DailySummary(ctx context.Context, date string) (domain.ResumenAsistencia, error) {
	return s.Repo.GetDailySummary(ctx, date)
}

func (s AttendanceService) SummaryByShift(ctx context.Context, shift, date string) (domain.ResumenAsistencia, error) {
	return s.Repo.GetSummaryByShift(ctx, shift, date)
}

// RegisterManual is RegistrarIngresoManual. The status is chosen by the
// preceptor (no time_slot to infer it from).
func (s AttendanceService) RegisterManual(ctx context.Context, studentID, courseID string, entryTimestamp time.Time, status string) (domain.RegistroAsistencia, error) {
	if studentID == "" || courseID == "" {
		return domain.RegistroAsistencia{}, domain.NewDomainError("Alumno y curso son obligatorios.", 400)
	}
	if !domain.ValidAttendanceStatus(status) {
		return domain.RegistroAsistencia{}, domain.NewDomainError("Estado inválido.", 400)
	}
	return s.Repo.RegisterManualCheckIn(ctx, studentID, courseID, entryTimestamp, status)
}

// RegisterEarlyDeparture is RegistrarRetiroAnticipado.
func (s AttendanceService) RegisterEarlyDeparture(ctx context.Context, recordID string, departureTime time.Time, reason, registeredBy string) (domain.RegistroAsistencia, error) {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return domain.RegistroAsistencia{}, domain.NewDomainError("El motivo del retiro es obligatorio.", 400)
	}
	if registeredBy == "" {
		return domain.RegistroAsistencia{}, domain.NewDomainError("Falta indicar quién registra el retiro.", 400)
	}
	rec, err := s.Repo.RegisterEarlyDeparture(ctx, recordID, departureTime, reason, registeredBy)
	if err != nil {
		return domain.RegistroAsistencia{}, err
	}
	if rec == nil {
		return domain.RegistroAsistencia{}, domain.NewDomainError("El registro de asistencia no existe.", 404)
	}
	return *rec, nil
}

// MarkNonComputable is MarcarNoComputable (manual, by the preceptor).
func (s AttendanceService) MarkNonComputable(ctx context.Context, recordID string) (domain.RegistroAsistencia, error) {
	rec, err := s.Repo.MarkNonComputable(ctx, recordID)
	if err != nil {
		return domain.RegistroAsistencia{}, err
	}
	if rec == nil {
		return domain.RegistroAsistencia{}, domain.NewDomainError("El registro de asistencia no existe.", 404)
	}
	return *rec, nil
}
