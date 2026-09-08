// Command api is the AAM backend HTTP server (Go rewrite of the former FastAPI
// service). It also carries a `migrate` subcommand for the embedded goose
// migrations.
//
//	go run ./cmd/api                 # start the server
//	go run ./cmd/api migrate up      # apply migrations
//	go run ./cmd/api migrate status  # show migration status
//	go run ./cmd/api migrate down    # roll back the last migration
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/paolaU7/AAM/backend/internal/adapter/auth"
	httpadapter "github.com/paolaU7/AAM/backend/internal/adapter/http"
	"github.com/paolaU7/AAM/backend/internal/adapter/postgres"
	"github.com/paolaU7/AAM/backend/internal/app"
	"github.com/paolaU7/AAM/backend/internal/config"
	"github.com/paolaU7/AAM/backend/internal/domain"
	"github.com/paolaU7/AAM/backend/internal/migrate"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	if len(os.Args) > 1 && os.Args[1] == "migrate" {
		runMigrate(cfg.DatabaseURL, os.Args[2:])
		return
	}

	ctx := context.Background()
	pool, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer pool.Close()

	srv := buildServer(cfg, pool)

	httpServer := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           srv.Router(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("AAM backend escuchando en http://localhost:%s", cfg.Port)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("http: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
	log.Println("bye")
}

func runMigrate(databaseURL string, args []string) {
	cmd := "up"
	if len(args) > 0 {
		cmd = args[0]
	}
	var err error
	switch cmd {
	case "up":
		err = migrate.Up(databaseURL)
	case "down":
		err = migrate.Down(databaseURL)
	case "status":
		err = migrate.Status(databaseURL)
	default:
		log.Fatalf("migrate: subcomando desconocido %q (up|down|status)", cmd)
	}
	if err != nil {
		log.Fatalf("migrate %s: %v", cmd, err)
	}
}

func buildServer(cfg config.Config, p *pgxpool.Pool) *httpadapter.Server {
	// repositories (adapters -> domain ports)
	courseRepo := postgres.NewCourseRepo(p)
	studentRepo := postgres.NewStudentRepo(p)
	specialtyRepo := postgres.NewSpecialtyRepo(p)
	settingsRepo := postgres.NewSchoolSettingsRepo(p)
	workshopRepo := postgres.NewWorkshopGroupRepo(p)
	attendanceRepo := postgres.NewAttendanceRepo(p)
	timeSlotRepo := postgres.NewTimeSlotRepo(p)
	classPeriodRepo := postgres.NewClassPeriodRepo(p)
	subjectRepo := postgres.NewSubjectRepo(p)
	applicabilityRepo := postgres.NewSubjectApplicabilityRepo(p)
	teacherRepo := postgres.NewTeacherRepo(p)
	cstRepo := postgres.NewCourseSubjectTeacherRepo(p)
	preceptorRepo := postgres.NewCoursePreceptorRepo(p)
	tempRepo := postgres.NewCoursePreceptorTempAssignmentRepo(p)
	notificationRepo := postgres.NewNotificationRepo(p)
	userRepo := postgres.NewUserRepo(p)
	deviceRepo := postgres.NewDeviceRepo(p)
	deviceSyncRepo := postgres.NewDeviceSyncRepo(p)
	overlap := postgres.NewOverlapDetector(p)

	// auth adapters
	hasher := auth.BcryptHasher{}
	tokens := auth.NewJWTIssuer(cfg.JWTSecret)
	secondary := domain.NewSecondaryAuthRegistry(auth.QRStaticAuthenticator{})

	return &httpadapter.Server{
		Courses:       app.CourseService{Repo: courseRepo, Specialty: specialtyRepo},
		Students:      app.StudentService{Repo: studentRepo, Courses: courseRepo, WorkshopGroup: workshopRepo},
		StudentImport: app.StudentImportService{Students: studentRepo, Courses: courseRepo, WorkshopGroup: workshopRepo},
		Attendance:    app.AttendanceService{Repo: attendanceRepo, Overlap: overlap},
		TimeSlots:     app.TimeSlotService{Repo: timeSlotRepo},
		ClassPeriods:  app.ClassPeriodService{Repo: classPeriodRepo, WorkshopGroup: workshopRepo},
		Academic: app.AcademicService{
			Subjects: subjectRepo, Applicability: applicabilityRepo, Teachers: teacherRepo,
			CourseSubject: cstRepo, Specialty: specialtyRepo, Courses: courseRepo,
		},
		Preceptors:    app.PreceptorService{Permanent: preceptorRepo, Temp: tempRepo},
		Specialties:   app.SpecialtyService{Repo: specialtyRepo, Settings: settingsRepo},
		WorkshopGroup: app.WorkshopGroupService{Repo: workshopRepo},
		Notifications: app.NotificationService{Repo: notificationRepo, Settings: settingsRepo},
		Users:         app.UserService{Repo: userRepo},

		Auth:          app.AuthService{Users: userRepo, Hasher: hasher, Tokens: tokens},
		DeviceSync:    app.DeviceSyncService{Sync: deviceSyncRepo},
		Devices:       deviceRepo,
		SecondaryAuth: secondary,
		Tokens:        tokens,
	}
}
