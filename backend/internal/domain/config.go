package domain

import (
	"context"
	"time"
)

// Entities and ports for the Dirección → "Configuración" section:
//   - General: shift labels, shift breaks, lunch window, panel alerts.
//   - Cursos: the academic structure (years, divisions per year, workshop
//     groups per division) and the active academic year.
//   - Dispositivos: entry points + NFC reader registry.
//
// Specialties, subjects and teachers are NOT managed here anymore — their own
// panel screens keep the parity CRUD.

// ── shifts: editable label per shift_type (no times — each course sets its
// own start/end in the Cursos section) ─────────────────────────────────────

type ShiftConfig struct {
	Shift string // 'morning' | 'afternoon' | 'evening'
	Label string
}

// ShiftBreak is one fixed recess of a shift (school-wide bell). A shift can
// have several. class_periods of type 'class' cannot overlap one (DB trigger).
type ShiftBreak struct {
	ID        string
	Shift     string
	Label     string
	StartTime string // "HH:MM"
	EndTime   string // "HH:MM"
}

// ── academic structure (Configuración → Cursos) ────────────────────────────

// YearDivisionStructure is one year of the structure tree: how many divisions
// it allows, and for each of them how many workshop groups.
type YearDivisionStructure struct {
	GradeYear     int
	DivisionCount int
	Divisions     []DivisionStructure
}

type DivisionStructure struct {
	Division           int
	WorkshopGroupCount int
}

// CoursesStructure is the whole Configuración → Cursos payload.
type CoursesStructure struct {
	CurrentAcademicYear int
	MaxGradeYear        int
	Years               []YearDivisionStructure
}

// ── entry points + devices (unchanged) ────────────────────────────────────

// EntryPoint is a physical spot where readers are installed (a door, a gate).
type EntryPoint struct {
	ID        string
	Name      string
	Location  *string
	CreatedAt time.Time
}

// DeviceConfig is the admin view of a registered reader. It never exposes the
// API key on reads.
type DeviceConfig struct {
	ID             string
	EntryPointID   string
	EntryPointName string
	Name           string
	IsActive       bool
	CreatedAt      time.Time
	RevokedAt      *time.Time
}

// DeviceCreated is the one-and-only response that includes the plaintext API
// key — returned by the create endpoint and never again.
type DeviceCreated struct {
	DeviceConfig
	APIKey string
}

// ── ports ─────────────────────────────────────────────────────────────────

// ShiftConfigRepo reads/updates the shift label rows.
type ShiftConfigRepo interface {
	GetAll(ctx context.Context) ([]ShiftConfig, error)
	UpdateLabel(ctx context.Context, shift, label string) (*ShiftConfig, error)
}

// ShiftBreakRepo persists `shift_breaks`.
type ShiftBreakRepo interface {
	GetByShift(ctx context.Context, shift string) ([]ShiftBreak, error)
	Create(ctx context.Context, shift, label, startTime, endTime string) (ShiftBreak, error)
	Delete(ctx context.Context, id string) (bool, error)
}

// CourseStructureRepo reads/writes year_structure + division_workshop_structure
// and the current_academic_year setting.
type CourseStructureRepo interface {
	Get(ctx context.Context) (CoursesStructure, error)
	// Replace reconciles the whole tree + current_academic_year + max_grade_year.
	// It must reject (as a *DomainError 400) any reduction that would leave an
	// existing `courses` / `workshop_groups` row outside the new limits.
	Replace(ctx context.Context, in CoursesStructure) (CoursesStructure, error)
	// MaxDivision is the loosest division_count across every year — used by the
	// parity /school-settings endpoint so the old course screens keep working.
	MaxDivision(ctx context.Context) (int, error)
}

// EntryPointRepo persists `entry_points`.
type EntryPointRepo interface {
	GetAll(ctx context.Context) ([]EntryPoint, error)
	Create(ctx context.Context, name string, location *string) (EntryPoint, error)
	Update(ctx context.Context, id, name string, location *string) (*EntryPoint, error)
	Delete(ctx context.Context, id string) (bool, error)
}

// DeviceConfigRepo persists `devices` for the admin panel.
type DeviceConfigRepo interface {
	GetAll(ctx context.Context) ([]DeviceConfig, error)
	GetByID(ctx context.Context, id string) (*DeviceConfig, error)
	Create(ctx context.Context, entryPointID, name, apiKey string) (DeviceConfig, error)
	// Revoke flips is_active=false, revoked_at=now() where not already revoked.
	Revoke(ctx context.Context, id string) (bool, error)
}
