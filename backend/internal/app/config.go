package app

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"regexp"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// Use cases for the Dirección → "Configuración" section:
//   - SchoolSettingsService: the school_settings row (alerts + lunch window +
//     max_grade_year + current_academic_year).
//   - ShiftConfigService / ShiftBreakService: General → Turnos / Recreos.
//   - CourseStructureService: General... no — Cursos: years, divisions per
//     year, workshop groups per division, active academic year.
//   - DeviceConfigService: entry points + NFC reader registry.

// ── school settings ─────────────────────────────────────────────────────────

type SchoolSettingsService struct {
	Repo domain.SchoolSettingsRepo
}

func (s SchoolSettingsService) Get(ctx context.Context) (domain.SchoolSettings, error) {
	return s.Repo.Get(ctx)
}

var reHHMM = regexp.MustCompile(`^([01]\d|2[0-3]):[0-5]\d$`)

// Update validates the alert thresholds and the lunch window before writing.
// max_grade_year and current_academic_year are owned by the Cursos structure
// endpoint; whatever comes in here for them is passed through unchanged (the
// General screen does not send them).
func (s SchoolSettingsService) Update(ctx context.Context, in domain.SchoolSettings) (domain.SchoolSettings, error) {
	for _, t := range []struct{ label, v string }{
		{"inicio del almuerzo", in.LunchStart},
		{"inicio del almuerzo con 5º módulo", in.LunchStartFifthModule},
		{"fin del almuerzo", in.LunchEnd},
	} {
		if !reHHMM.MatchString(t.v) {
			return domain.SchoolSettings{}, domain.NewDomainError("Horario inválido para "+t.label+" (usá HH:MM).", 400)
		}
	}
	if in.LunchStart >= in.LunchEnd || in.LunchStartFifthModule >= in.LunchEnd {
		return domain.SchoolSettings{}, domain.NewDomainError("El fin del almuerzo tiene que ser posterior a su inicio.", 400)
	}
	switch {
	case in.ConsecutiveAbsencesAlertThreshold < 1:
		return domain.SchoolSettings{}, domain.NewDomainError("El umbral de faltas consecutivas debe ser mayor a 0.", 400)
	case in.PreceptorTempAssignmentAlertDays < 0:
		return domain.SchoolSettings{}, domain.NewDomainError("Los días de aviso de reemplazo no pueden ser negativos.", 400)
	case in.ScheduleExceptionAlertDays < 0:
		return domain.SchoolSettings{}, domain.NewDomainError("Los días de aviso de excepción de horario no pueden ser negativos.", 400)
	}

	// Keep the structure-owned fields as stored (the General screen omits them).
	cur, err := s.Repo.Get(ctx)
	if err != nil {
		return domain.SchoolSettings{}, err
	}
	in.MaxGradeYear = cur.MaxGradeYear
	in.CurrentAcademicYear = cur.CurrentAcademicYear
	return s.Repo.Update(ctx, in)
}

// ── shifts (labels) ─────────────────────────────────────────────────────────

type ShiftConfigService struct {
	Repo domain.ShiftConfigRepo
}

func (s ShiftConfigService) List(ctx context.Context) ([]domain.ShiftConfig, error) {
	return s.Repo.GetAll(ctx)
}

var validShifts = map[string]bool{"morning": true, "afternoon": true, "evening": true}

func (s ShiftConfigService) Rename(ctx context.Context, shift, label string) (*domain.ShiftConfig, error) {
	if !validShifts[shift] {
		return nil, domain.NewDomainError("Turno inválido.", 400)
	}
	label = strings.TrimSpace(label)
	if label == "" {
		return nil, domain.NewDomainError("El nombre del turno es obligatorio.", 400)
	}
	return s.Repo.UpdateLabel(ctx, shift, label)
}

// ── shift breaks (recreos) ─────────────────────────────────────────────────

type ShiftBreakService struct {
	Repo domain.ShiftBreakRepo
}

func (s ShiftBreakService) ListByShift(ctx context.Context, shift string) ([]domain.ShiftBreak, error) {
	if !validShifts[shift] {
		return nil, domain.NewDomainError("Turno inválido.", 400)
	}
	return s.Repo.GetByShift(ctx, shift)
}

func (s ShiftBreakService) Create(ctx context.Context, shift, label, startTime, endTime string) (domain.ShiftBreak, error) {
	if !validShifts[shift] {
		return domain.ShiftBreak{}, domain.NewDomainError("Turno inválido.", 400)
	}
	label = strings.TrimSpace(label)
	if label == "" {
		label = "Recreo"
	}
	if !reHHMM.MatchString(startTime) || !reHHMM.MatchString(endTime) {
		return domain.ShiftBreak{}, domain.NewDomainError("Horario inválido (usá HH:MM).", 400)
	}
	if startTime >= endTime {
		return domain.ShiftBreak{}, domain.NewDomainError("La hora de fin del recreo tiene que ser posterior a la de inicio.", 400)
	}
	return s.Repo.Create(ctx, shift, label, startTime, endTime)
}

func (s ShiftBreakService) Delete(ctx context.Context, id string) (bool, error) {
	return s.Repo.Delete(ctx, id)
}

// ── academic structure (Configuración → Cursos) ──────────────────────────

type CourseStructureService struct {
	Repo domain.CourseStructureRepo
}

func (s CourseStructureService) Get(ctx context.Context) (domain.CoursesStructure, error) {
	return s.Repo.Get(ctx)
}

func (s CourseStructureService) Replace(ctx context.Context, in domain.CoursesStructure) (domain.CoursesStructure, error) {
	return s.Repo.Replace(ctx, in)
}

// MaxDivision feeds the parity /school-settings route.
func (s CourseStructureService) MaxDivision(ctx context.Context) (int, error) {
	return s.Repo.MaxDivision(ctx)
}

// ── NFC-reader registry: entry points + devices ────────────────────────────

type DeviceConfigService struct {
	EntryPoints domain.EntryPointRepo
	Devices     domain.DeviceConfigRepo
}

func (s DeviceConfigService) ListEntryPoints(ctx context.Context) ([]domain.EntryPoint, error) {
	return s.EntryPoints.GetAll(ctx)
}

func (s DeviceConfigService) CreateEntryPoint(ctx context.Context, name string, location *string) (domain.EntryPoint, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return domain.EntryPoint{}, domain.NewDomainError("El nombre del punto de acceso es obligatorio.", 400)
	}
	return s.EntryPoints.Create(ctx, name, nilIfEmpty(location))
}

func (s DeviceConfigService) UpdateEntryPoint(ctx context.Context, id, name string, location *string) (*domain.EntryPoint, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, domain.NewDomainError("El nombre del punto de acceso es obligatorio.", 400)
	}
	return s.EntryPoints.Update(ctx, id, name, nilIfEmpty(location))
}

func (s DeviceConfigService) DeleteEntryPoint(ctx context.Context, id string) (bool, error) {
	return s.EntryPoints.Delete(ctx, id)
}

func (s DeviceConfigService) ListDevices(ctx context.Context) ([]domain.DeviceConfig, error) {
	return s.Devices.GetAll(ctx)
}

// CreateDevice mints the API key (32 bytes from crypto/rand, base64url) and
// returns it once, inside DeviceCreated. It is never retrievable afterwards.
func (s DeviceConfigService) CreateDevice(ctx context.Context, entryPointID, name string) (domain.DeviceCreated, error) {
	name = strings.TrimSpace(name)
	if strings.TrimSpace(entryPointID) == "" {
		return domain.DeviceCreated{}, domain.NewDomainError("Seleccioná el punto de acceso.", 400)
	}
	if name == "" {
		return domain.DeviceCreated{}, domain.NewDomainError("El nombre del dispositivo es obligatorio.", 400)
	}
	key, err := generateAPIKey()
	if err != nil {
		return domain.DeviceCreated{}, err
	}
	dev, err := s.Devices.Create(ctx, entryPointID, name, key)
	if err != nil {
		return domain.DeviceCreated{}, err
	}
	return domain.DeviceCreated{DeviceConfig: dev, APIKey: key}, nil
}

// RevokeDevice flips the device inactive. Returns a 404 (device unknown) or a
// 400 (already revoked) DomainError so the handler doesn't need the detail.
func (s DeviceConfigService) RevokeDevice(ctx context.Context, id string) error {
	cur, err := s.Devices.GetByID(ctx, id)
	if err != nil {
		return err
	}
	if cur == nil {
		return domain.NewDomainError("Dispositivo no encontrado.", 404)
	}
	if cur.RevokedAt != nil || !cur.IsActive {
		return domain.NewDomainError("El dispositivo ya estaba revocado.", 400)
	}
	ok, err := s.Devices.Revoke(ctx, id)
	if err != nil {
		return err
	}
	if !ok {
		return domain.NewDomainError("El dispositivo ya estaba revocado.", 400)
	}
	return nil
}

func generateAPIKey() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return "aamk_" + base64.RawURLEncoding.EncodeToString(buf), nil
}
