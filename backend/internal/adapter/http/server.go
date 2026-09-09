package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/paolaU7/AAM/backend/internal/app"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// Server bundles every use-case service and the auth/device dependencies, and
// exposes them as HTTP handlers.
type Server struct {
	Courses       app.CourseService
	Students      app.StudentService
	StudentImport app.StudentImportService
	Attendance    app.AttendanceService
	TimeSlots     app.TimeSlotService
	ClassPeriods  app.ClassPeriodService
	Academic      app.AcademicService
	Preceptors    app.PreceptorService
	Specialties   app.SpecialtyService
	WorkshopGroup app.WorkshopGroupService
	Notifications app.NotificationService
	Users         app.UserService

	// New in the Go backend (scaffolding).
	Auth          app.AuthService
	DeviceSync    app.DeviceSyncService
	Devices       domain.DeviceRepo
	SecondaryAuth *domain.SecondaryAuthRegistry
	Tokens        domain.TokenIssuer

	// Dirección → "Configuración" section.
	SchoolSettings  app.SchoolSettingsService
	Shifts          app.ShiftConfigService
	ShiftBreaks     app.ShiftBreakService
	CourseStructure app.CourseStructureService
	DeviceConfig    app.DeviceConfigService
}

// Router builds the chi router with all routes mounted.
func (s *Server) Router() http.Handler {
	r := chi.NewRouter()

	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.NotFound(func(w http.ResponseWriter, r *http.Request) { detail(w, http.StatusNotFound, "No encontrado") })
	r.MethodNotAllowed(func(w http.ResponseWriter, r *http.Request) {
		detail(w, http.StatusMethodNotAllowed, "Método no permitido")
	})

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// ── parity routes (consumed by the Flutter panel) ───────────────────────
	s.mountCourses(r)
	s.mountStudents(r)
	s.mountUsers(r)
	s.mountAttendance(r)
	s.mountAcademic(r)
	s.mountWorkshopGroups(r)
	s.mountSpecialties(r)
	s.mountNotifications(r)

	// ── new: panel auth + ESP32 device endpoints ────────────────────────────
	s.mountAuth(r)
	s.mountDevice(r)

	// ── Dirección → Configuración (placeholder role gate, see requirePrincipal) ─
	r.Group(func(r chi.Router) {
		r.Use(s.requirePrincipal)
		s.mountConfig(r)
	})

	return r
}
