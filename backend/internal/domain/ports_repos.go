package domain

import (
	"context"
	"time"
)

// StudentRepo persists the panel-facing Alumno against `students`.
type StudentRepo interface {
	GetAlumnos(ctx context.Context, includeInactive bool) ([]Alumno, error)
	GetAlumnoPorID(ctx context.Context, id string) (*Alumno, error)
	GetAlumnosPorCurso(ctx context.Context, cursoID string) ([]Alumno, error)
	ActualizarAlumno(ctx context.Context, id string, a Alumno) (*Alumno, error)
	ToggleActive(ctx context.Context, id string) (*Alumno, error)
	ExisteDNI(ctx context.Context, dni string) (bool, error)
	CrearAlumnoManual(ctx context.Context, p CrearAlumnoParams) (*Alumno, error)
	// EliminarAlumno hard-deletes. Returns a *DomainError (400) if the student
	// is still active — only a student already given de baja can be deleted —
	// or (409) if it has associated records (attendance, NFC bracelet, etc.).
	EliminarAlumno(ctx context.Context, id string) (bool, error)
}

type CrearAlumnoParams struct {
	FirstName       string
	LastName        string
	NationalID      string
	CourseID        string
	WorkshopGroupID *string
}

// CourseRepo persists `courses`.
type CourseRepo interface {
	GetCourses(ctx context.Context) ([]Course, error)
	GetCourseByID(ctx context.Context, id string) (*Course, error)
	// ResolveCourse returns the course for the (academic_year, grade_year,
	// division) UNIQUE triple, or nil. Used by the Excel import flow.
	ResolveCourse(ctx context.Context, academicYear, gradeYear, division int) (*Course, error)
	CreateCourse(ctx context.Context, academicYear, gradeYear, division int, specialtyID string) (*Course, error)
	UpdateCourse(ctx context.Context, id string, academicYear, gradeYear, division int, specialtyID string) (*Course, error)
}

// AttendanceRepo persists `attendance_records` + `early_departures`.
type AttendanceRepo interface {
	GetByCourseAndDate(ctx context.Context, courseID, date string) ([]RegistroAsistencia, error)
	GetDailySummary(ctx context.Context, date string) (ResumenAsistencia, error)
	// GetSummaryByShift only counts records tied to a time_slot with that shift.
	GetSummaryByShift(ctx context.Context, shift, date string) (ResumenAsistencia, error)
	RegisterManualCheckIn(ctx context.Context, studentID, courseID string, entryTimestamp time.Time, status string) (RegistroAsistencia, error)
	RegisterEarlyDeparture(ctx context.Context, recordID string, departureTime time.Time, reason, registeredBy string) (*RegistroAsistencia, error)
	MarkNonComputable(ctx context.Context, recordID string) (*RegistroAsistencia, error)
}

// ClassPeriodRepo persists `class_periods` (detailed schedule grid).
type ClassPeriodRepo interface {
	GetByCourse(ctx context.Context, courseID string) ([]ClassPeriod, error)
	Create(ctx context.Context, p CreateClassPeriodParams) (ClassPeriod, error)
	Delete(ctx context.Context, id string) (bool, error)
}

type CreateClassPeriodParams struct {
	CourseID        string
	WorkshopGroupID *string
	DayOfWeek       int
	Shift           string
	PeriodType      string
	StartTime       string
	EndTime         string
	SubjectID       *string
	TeacherID       *string
	IsFifthModule   bool
}

// TimeSlotRepo persists `time_slots` (attendance windows).
type TimeSlotRepo interface {
	GetByCourse(ctx context.Context, courseID string) ([]TimeSlot, error)
	GetByWorkshopGroup(ctx context.Context, workshopGroupID string) ([]TimeSlot, error)
	Create(ctx context.Context, p CreateTimeSlotParams) (TimeSlot, error)
	Delete(ctx context.Context, id string) (bool, error)
}

type CreateTimeSlotParams struct {
	CourseID             *string
	WorkshopGroupID      *string
	Shift                string
	ActivityType         string
	DayOfWeek            int
	StartTime            string
	EndTime              string
	LateToleranceMinutes int
}

// SubjectRepo persists `subjects`.
type SubjectRepo interface {
	// GetAll: no filters -> full catalogue. With gradeYear+specialtyID -> only
	// subjects enabled (via subject_applicability) for that combination. Either
	// way each row carries its full subject_applicability list embedded, so
	// the Materias screen can filter by año/especialidad without N+1 requests.
	GetAll(ctx context.Context, gradeYear *int, specialtyID *string) ([]SubjectWithApplicability, error)
	GetByID(ctx context.Context, id string) (*Subject, error)
	// Create inserts with the given short_code and short_code_auto = true —
	// there's nothing to have manually overridden yet on a brand-new subject.
	Create(ctx context.Context, name, subjectType, shortCode string) (Subject, error)
	// UpdateShortCode sets short_code (and short_code_auto) directly. Used
	// both for the automatic recompute (auto = true, on create/applicability
	// change) and for a manual edit (auto = false). Returns nil if the
	// subject doesn't exist.
	UpdateShortCode(ctx context.Context, id, shortCode string, auto bool) (*Subject, error)
	// UpdateDetails changes name + subject_type together (the "editar
	// materia" pencil in the Materias screen). Returns a *DomainError (409)
	// on a duplicate name, or nil if the subject doesn't exist.
	UpdateDetails(ctx context.Context, id, name, subjectType string) (*Subject, error)
	// ToggleActive flips is_active (baja lógica). Returns nil if the subject
	// doesn't exist.
	ToggleActive(ctx context.Context, id string) (*Subject, error)
	// Delete hard-deletes. Returns a *DomainError (400) if the subject is
	// still active — only one already given de baja can be deleted — or
	// (409) if it has associated records (courses, teachers, schedule).
	Delete(ctx context.Context, id string) (bool, error)
}

// SubjectApplicabilityRepo persists `subject_applicability`.
type SubjectApplicabilityRepo interface {
	GetBySubject(ctx context.Context, subjectID string) ([]SubjectApplicability, error)
	Add(ctx context.Context, subjectID string, gradeYear int, specialtyID string) (SubjectApplicability, error)
	Remove(ctx context.Context, id string) (bool, error)
	// SubjectIDFor returns the subject_id owning applicability row id, or ""
	// if the row doesn't exist. Used to recompute that subject's short_code
	// after the row is removed.
	SubjectIDFor(ctx context.Context, id string) (string, error)
}

// TeacherRepo persists `teachers`.
type TeacherRepo interface {
	GetAll(ctx context.Context) ([]Teacher, error)
	Create(ctx context.Context, fullName string, email, phone *string) (Teacher, error)
}

// CourseSubjectTeacherRepo persists `course_subject_teachers`.
type CourseSubjectTeacherRepo interface {
	GetByCourse(ctx context.Context, courseID string) ([]SubjectTeacherAssignment, error)
	GetByTeacher(ctx context.Context, teacherID string) ([]SubjectTeacherAssignment, error)
	// Assign upserts on (course_id, subject_id).
	Assign(ctx context.Context, courseID, subjectID, teacherID string) (SubjectTeacherAssignment, error)
	Remove(ctx context.Context, courseID, subjectID string) (bool, error)
}

// CoursePreceptorRepo persists `course_preceptors`.
type CoursePreceptorRepo interface {
	GetByCourse(ctx context.Context, courseID string) ([]CoursePreceptor, error)
	// Assign upserts on (course_id, shift).
	Assign(ctx context.Context, courseID, shift, preceptorID string) (CoursePreceptor, error)
	Remove(ctx context.Context, courseID, shift string) (bool, error)
}

// CoursePreceptorTempAssignmentRepo persists `course_preceptor_temp_assignments`.
type CoursePreceptorTempAssignmentRepo interface {
	GetByCourse(ctx context.Context, courseID string) ([]CoursePreceptorTempAssignment, error)
	Create(ctx context.Context, p CreateTempAssignmentParams) (CoursePreceptorTempAssignment, error)
	Delete(ctx context.Context, id string) (bool, error)
}

type CreateTempAssignmentParams struct {
	CourseID    string
	Shift       string
	PreceptorID string
	StartDate   string // YYYY-MM-DD
	EndDate     string // YYYY-MM-DD
	Reason      *string
	CreatedBy   string
}

// SpecialtyRepo persists `specialties`.
type SpecialtyRepo interface {
	GetAll(ctx context.Context) ([]Specialty, error)
	GetByID(ctx context.Context, id string) (*Specialty, error)
}

// SchoolSettingsRepo reads and writes the single `school_settings` row.
type SchoolSettingsRepo interface {
	Get(ctx context.Context) (SchoolSettings, error)
	Update(ctx context.Context, s SchoolSettings) (SchoolSettings, error)
}

// WorkshopGroupRepo persists `workshop_groups`.
type WorkshopGroupRepo interface {
	GetAll(ctx context.Context) ([]WorkshopGroup, error)
	GetByCourse(ctx context.Context, courseID string) ([]WorkshopGroup, error)
}

// NotificationRepo computes the header-bell alerts on the fly.
type NotificationRepo interface {
	GetAlerts(ctx context.Context, preceptorTempAlertDays, scheduleExceptionAlertDays, consecutiveAbsencesThreshold int) ([]Notification, error)
}

// UserRepo persists `users`.
type UserRepo interface {
	GetUsuarios(ctx context.Context) ([]Usuario, error)
	GetUsuarioPorID(ctx context.Context, id string) (*Usuario, error)
	// CrearUsuario derives email/username from the name and generates the
	// initial password. Returns the user and the plaintext password (exposed
	// only this once).
	CrearUsuario(ctx context.Context, nombre, apellido string, rol RolUsuario) (Usuario, string, error)
	ToggleActive(ctx context.Context, id string) (*Usuario, error)
	ActualizarUsuario(ctx context.Context, id, nombre, apellido string, rol RolUsuario) (*Usuario, error)
	// EliminarUsuario hard-deletes. Returns a *DomainError (409) if the user
	// has associated records.
	EliminarUsuario(ctx context.Context, id string) (bool, error)
	// ResetPassword generates and persists a new password; returns the
	// plaintext (or nil if the user does not exist).
	ResetPassword(ctx context.Context, id string) (*string, error)
	// FindAuthByUsername returns the credential material for login, or nil.
	FindAuthByUsername(ctx context.Context, username string) (*UsuarioAuth, error)
}

// UsuarioAuth is the credential material needed to authenticate a panel user.
type UsuarioAuth struct {
	User         Usuario
	PasswordHash string
}
