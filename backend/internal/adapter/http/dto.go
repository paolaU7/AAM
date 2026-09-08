package http

import (
	"time"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// ── courses ──────────────────────────────────────────────────────────────────

type courseDTO struct {
	ID            string `json:"id"`
	AcademicYear  int    `json:"academic_year"`
	GradeYear     int    `json:"grade_year"`
	Division      int    `json:"division"`
	SpecialtyID   string `json:"specialty_id"`
	SpecialtyName string `json:"specialty_name"`
	TotalStudents int    `json:"total_students"`
	Name          string `json:"name"`
}

func toCourseDTO(c domain.Course) courseDTO {
	return courseDTO{c.ID, c.AcademicYear, c.GradeYear, c.Division, c.SpecialtyID, c.SpecialtyName, c.TotalStudents, c.Name}
}

// ── time slots ───────────────────────────────────────────────────────────────

type timeSlotDTO struct {
	ID                   string  `json:"id"`
	CourseID             *string `json:"course_id"`
	WorkshopGroupID      *string `json:"workshop_group_id"`
	Shift                string  `json:"shift"`
	ActivityType         string  `json:"activity_type"`
	DayOfWeek            int     `json:"day_of_week"`
	StartTime            string  `json:"start_time"`
	EndTime              string  `json:"end_time"`
	LateToleranceMinutes int     `json:"late_tolerance_minutes"`
}

func toTimeSlotDTO(t domain.TimeSlot) timeSlotDTO {
	return timeSlotDTO{t.ID, t.CourseID, t.WorkshopGroupID, t.Shift, t.ActivityType, t.DayOfWeek, t.StartTime, t.EndTime, t.LateToleranceMinutes}
}

// ── class periods ────────────────────────────────────────────────────────────

type classPeriodDTO struct {
	ID              string  `json:"id"`
	CourseID        string  `json:"course_id"`
	WorkshopGroupID *string `json:"workshop_group_id"`
	DayOfWeek       int     `json:"day_of_week"`
	Shift           string  `json:"shift"`
	PeriodOrder     int     `json:"period_order"`
	PeriodType      string  `json:"period_type"`
	StartTime       string  `json:"start_time"`
	EndTime         string  `json:"end_time"`
	IsFifthModule   bool    `json:"is_fifth_module"`
	SubjectID       *string `json:"subject_id"`
	SubjectName     *string `json:"subject_name"`
	TeacherID       *string `json:"teacher_id"`
	TeacherName     *string `json:"teacher_name"`
}

func toClassPeriodDTO(p domain.ClassPeriod) classPeriodDTO {
	return classPeriodDTO{p.ID, p.CourseID, p.WorkshopGroupID, p.DayOfWeek, p.Shift, p.PeriodOrder, p.PeriodType,
		p.StartTime, p.EndTime, p.IsFifthModule, p.SubjectID, p.SubjectName, p.TeacherID, p.TeacherName}
}

// ── subject / teacher ────────────────────────────────────────────────────────

type subjectDTO struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	SubjectType string `json:"subject_type"`
}

type subjectApplicabilityDTO struct {
	ID            string `json:"id"`
	SubjectID     string `json:"subject_id"`
	GradeYear     int    `json:"grade_year"`
	SpecialtyID   string `json:"specialty_id"`
	SpecialtyName string `json:"specialty_name"`
}

type teacherDTO struct {
	ID       string  `json:"id"`
	FullName string  `json:"full_name"`
	Email    *string `json:"email"`
	Phone    *string `json:"phone"`
}

type subjectTeacherDTO struct {
	CourseID     string  `json:"course_id"`
	SubjectID    string  `json:"subject_id"`
	SubjectName  string  `json:"subject_name"`
	SubjectType  string  `json:"subject_type"`
	TeacherID    string  `json:"teacher_id"`
	TeacherName  string  `json:"teacher_name"`
	TeacherEmail *string `json:"teacher_email"`
	TeacherPhone *string `json:"teacher_phone"`
	CourseName   *string `json:"course_name"`
}

func toSubjectDTO(s domain.Subject) subjectDTO {
	return subjectDTO{s.ID, s.Name, s.SubjectType}
}

func toApplicabilityDTO(a domain.SubjectApplicability) subjectApplicabilityDTO {
	return subjectApplicabilityDTO{a.ID, a.SubjectID, a.GradeYear, a.SpecialtyID, a.SpecialtyName}
}

func toTeacherDTO(t domain.Teacher) teacherDTO {
	return teacherDTO{t.ID, t.FullName, t.Email, t.Phone}
}

func toSubjectTeacherDTO(a domain.SubjectTeacherAssignment) subjectTeacherDTO {
	return subjectTeacherDTO{a.CourseID, a.SubjectID, a.SubjectName, a.SubjectType, a.TeacherID, a.TeacherName,
		a.TeacherEmail, a.TeacherPhone, a.CourseName}
}

// ── preceptors ───────────────────────────────────────────────────────────────

type coursePreceptorDTO struct {
	CourseID      string `json:"course_id"`
	Shift         string `json:"shift"`
	PreceptorID   string `json:"preceptor_id"`
	PreceptorName string `json:"preceptor_name"`
}

type coursePreceptorTempDTO struct {
	ID            string  `json:"id"`
	CourseID      string  `json:"course_id"`
	Shift         string  `json:"shift"`
	PreceptorID   string  `json:"preceptor_id"`
	PreceptorName string  `json:"preceptor_name"`
	StartDate     string  `json:"start_date"`
	EndDate       string  `json:"end_date"`
	Reason        *string `json:"reason"`
}

func toCoursePreceptorDTO(c domain.CoursePreceptor) coursePreceptorDTO {
	return coursePreceptorDTO{c.CourseID, c.Shift, c.PreceptorID, c.PreceptorName}
}

func toCoursePreceptorTempDTO(a domain.CoursePreceptorTempAssignment) coursePreceptorTempDTO {
	return coursePreceptorTempDTO{a.ID, a.CourseID, a.Shift, a.PreceptorID, a.PreceptorName, a.StartDate, a.EndDate, a.Reason}
}

// ── workshop groups / specialties / notifications ────────────────────────────

type workshopGroupDTO struct {
	ID         string `json:"id"`
	CourseID   string `json:"course_id"`
	GroupLabel string `json:"group_label"`
}

type specialtyDTO struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	IsBasicCycle bool   `json:"is_basic_cycle"`
}

type schoolSettingsDTO struct {
	MaxGradeYear int `json:"max_grade_year"`
	MaxDivision  int `json:"max_division"`
}

type notificationDTO struct {
	Type    string `json:"type"`
	Message string `json:"message"`
}

// ── students ─────────────────────────────────────────────────────────────────

type alumnoDTO struct {
	ID                   string  `json:"id"`
	Nombre               string  `json:"nombre"`
	Apellido             string  `json:"apellido"`
	NombreCompleto       string  `json:"nombre_completo"`
	DNI                  string  `json:"dni"`
	CursoID              string  `json:"curso_id"`
	Curso                string  `json:"curso"`
	Recursante           bool    `json:"recursante"`
	PorcentajeAsistencia float64 `json:"porcentaje_asistencia"`
	EstadoRegularidad    string  `json:"estado_regularidad"`
	AcademicYear         int     `json:"academic_year"`
	GradeYear            int     `json:"grade_year"`
	Division             int     `json:"division"`
	IsActive             bool    `json:"is_active"`
	WorkshopGroupID      *string `json:"workshop_group_id"`
	Taller               *string `json:"taller"`
}

func toAlumnoDTO(a domain.Alumno) alumnoDTO {
	return alumnoDTO{
		ID: a.ID, Nombre: a.Nombre, Apellido: a.Apellido, NombreCompleto: a.NombreCompleto(),
		DNI: a.DNI, CursoID: a.CursoID, Curso: a.Curso, Recursante: a.Recursante,
		PorcentajeAsistencia: a.PorcentajeAsistencia, EstadoRegularidad: string(a.EstadoRegularidad()),
		AcademicYear: a.AcademicYear, GradeYear: a.GradeYear, Division: a.Division,
		IsActive: a.IsActive, WorkshopGroupID: a.WorkshopGroupID, Taller: a.Taller,
	}
}

// ── users ────────────────────────────────────────────────────────────────────

type userDTO struct {
	ID             string `json:"id"`
	Nombre         string `json:"nombre"`
	Apellido       string `json:"apellido"`
	NombreCompleto string `json:"nombre_completo"`
	Username       string `json:"username"`
	Email          string `json:"email"`
	Rol            string `json:"rol"`
	Activo         bool   `json:"activo"`
}

func toUserDTO(u domain.Usuario) userDTO {
	return userDTO{u.ID, u.Nombre, u.Apellido, u.NombreCompleto(), u.Username(), u.Email, string(u.Rol), u.Activo}
}

// ── attendance ───────────────────────────────────────────────────────────────

type registroDTO struct {
	ID              string     `json:"id"`
	StudentID       string     `json:"student_id"`
	StudentName     string     `json:"student_name"`
	CourseID        string     `json:"course_id"`
	EntryTimestamp  time.Time  `json:"entry_timestamp"`
	Source          string     `json:"source"`
	Status          string     `json:"status"`
	DepartureTime   *time.Time `json:"departure_time"`
	DepartureReason *string    `json:"departure_reason"`
}

func toRegistroDTO(r domain.RegistroAsistencia) registroDTO {
	return registroDTO{
		ID: r.ID, StudentID: r.StudentID, StudentName: r.StudentName, CourseID: r.CourseID,
		EntryTimestamp: r.EntryTimestamp, Source: r.Source, Status: r.Status,
		DepartureTime: r.DepartureTime, DepartureReason: r.DepartureReason,
	}
}

func toResumenDTO(s domain.ResumenAsistencia) resumenDTO {
	return resumenDTO{s.Date, s.Present, s.Absent, s.Late, s.NonComputableAbsence, s.EarlyDepartures, s.Total}
}

type resumenDTO struct {
	Date                 string `json:"date"`
	Present              int    `json:"present"`
	Absent               int    `json:"absent"`
	Late                 int    `json:"late"`
	NonComputableAbsence int    `json:"non_computable_absence"`
	EarlyDepartures      int    `json:"early_departures"`
	Total                int    `json:"total"`
}
