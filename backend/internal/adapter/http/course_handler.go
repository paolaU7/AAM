package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

func (s *Server) mountCourses(r chi.Router) {
	r.Route("/courses", func(r chi.Router) {
		r.Get("/", s.listCourses)
		r.Post("/", s.createCourse)
		r.Get("/{id}", s.getCourse)
		r.Patch("/{id}", s.updateCourse)

		r.Get("/{id}/time-slots", s.listCourseTimeSlots)
		r.Post("/{id}/time-slots", s.createCourseTimeSlot)
		r.Delete("/{id}/time-slots/{slotID}", s.deleteCourseTimeSlot)

		r.Get("/{id}/class-periods", s.listClassPeriods)
		r.Post("/{id}/class-periods", s.createClassPeriod)
		r.Delete("/{id}/class-periods/{periodID}", s.deleteClassPeriod)

		r.Get("/{id}/subject-teachers", s.listCourseSubjectTeachers)
		r.Post("/{id}/subject-teachers", s.assignCourseSubjectTeacher)
		r.Delete("/{id}/subject-teachers/{subjectID}", s.removeCourseSubjectTeacher)

		r.Get("/{id}/preceptors", s.listCoursePreceptors)
		r.Post("/{id}/preceptors", s.assignCoursePreceptor)
		r.Delete("/{id}/preceptors/{shift}", s.removeCoursePreceptor)

		r.Get("/{id}/preceptor-temp-assignments", s.listCoursePreceptorTemp)
		r.Post("/{id}/preceptor-temp-assignments", s.createCoursePreceptorTemp)
		r.Delete("/{id}/preceptor-temp-assignments/{assignmentID}", s.deleteCoursePreceptorTemp)

		r.Get("/{id}/workshop-groups", s.listCourseWorkshopGroups)
	})
}

// ── courses ──────────────────────────────────────────────────────────────────

func (s *Server) listCourses(w http.ResponseWriter, r *http.Request) {
	courses, err := s.Courses.List(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(courses, toCourseDTO))
}

type courseBody struct {
	AcademicYear int    `json:"academic_year"`
	GradeYear    int    `json:"grade_year"`
	Division     int    `json:"division"`
	SpecialtyID  string `json:"specialty_id"`
}

func (s *Server) createCourse(w http.ResponseWriter, r *http.Request) {
	var b courseBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	c, err := s.Courses.Create(r.Context(), b.AcademicYear, b.GradeYear, b.Division, b.SpecialtyID)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toCourseDTO(*c))
}

func (s *Server) getCourse(w http.ResponseWriter, r *http.Request) {
	c, err := s.Courses.Get(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if c == nil {
		detail(w, http.StatusNotFound, "Course not found")
		return
	}
	writeJSON(w, http.StatusOK, toCourseDTO(*c))
}

func (s *Server) updateCourse(w http.ResponseWriter, r *http.Request) {
	var b courseBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	c, err := s.Courses.Update(r.Context(), urlParam(r, "id"), b.AcademicYear, b.GradeYear, b.Division, b.SpecialtyID)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toCourseDTO(*c))
}

// ── time slots ───────────────────────────────────────────────────────────────

func (s *Server) listCourseTimeSlots(w http.ResponseWriter, r *http.Request) {
	slots, err := s.TimeSlots.ByCourse(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(slots, toTimeSlotDTO))
}

type timeSlotBody struct {
	Shift                string `json:"shift"`
	ActivityType         string `json:"activity_type"`
	DayOfWeek            int    `json:"day_of_week"`
	StartTime            string `json:"start_time"`
	EndTime              string `json:"end_time"`
	LateToleranceMinutes int    `json:"late_tolerance_minutes"`
}

func (s *Server) createCourseTimeSlot(w http.ResponseWriter, r *http.Request) {
	var b timeSlotBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	slot, err := s.TimeSlots.CreateForCourse(r.Context(), urlParam(r, "id"), b.Shift, b.ActivityType,
		b.DayOfWeek, b.StartTime, b.EndTime, b.LateToleranceMinutes)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toTimeSlotDTO(slot))
}

func (s *Server) deleteCourseTimeSlot(w http.ResponseWriter, r *http.Request) {
	ok, err := s.TimeSlots.Delete(r.Context(), urlParam(r, "slotID"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Time slot not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── class periods ────────────────────────────────────────────────────────────

func (s *Server) listClassPeriods(w http.ResponseWriter, r *http.Request) {
	periods, err := s.ClassPeriods.ByCourse(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(periods, toClassPeriodDTO))
}

type classPeriodBody struct {
	DayOfWeek       int     `json:"day_of_week"`
	Shift           string  `json:"shift"`
	PeriodType      string  `json:"period_type"`
	StartTime       string  `json:"start_time"`
	EndTime         string  `json:"end_time"`
	SubjectID       *string `json:"subject_id"`
	TeacherID       *string `json:"teacher_id"`
	IsFifthModule   bool    `json:"is_fifth_module"`
	WorkshopGroupID *string `json:"workshop_group_id"`
}

func (s *Server) createClassPeriod(w http.ResponseWriter, r *http.Request) {
	var b classPeriodBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	p, err := s.ClassPeriods.Create(r.Context(), domain.CreateClassPeriodParams{
		CourseID:        urlParam(r, "id"),
		WorkshopGroupID: b.WorkshopGroupID,
		DayOfWeek:       b.DayOfWeek,
		Shift:           b.Shift,
		PeriodType:      b.PeriodType,
		StartTime:       b.StartTime,
		EndTime:         b.EndTime,
		SubjectID:       b.SubjectID,
		TeacherID:       b.TeacherID,
		IsFifthModule:   b.IsFifthModule,
	})
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toClassPeriodDTO(p))
}

func (s *Server) deleteClassPeriod(w http.ResponseWriter, r *http.Request) {
	ok, err := s.ClassPeriods.Delete(r.Context(), urlParam(r, "periodID"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Class period not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── subject-teachers ─────────────────────────────────────────────────────────

func (s *Server) listCourseSubjectTeachers(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Academic.CourseSubjectTeachers(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toSubjectTeacherDTO))
}

func (s *Server) assignCourseSubjectTeacher(w http.ResponseWriter, r *http.Request) {
	var b struct {
		SubjectID string `json:"subject_id"`
		TeacherID string `json:"teacher_id"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	row, err := s.Academic.AssignCourseSubjectTeacher(r.Context(), urlParam(r, "id"), b.SubjectID, b.TeacherID)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toSubjectTeacherDTO(row))
}

func (s *Server) removeCourseSubjectTeacher(w http.ResponseWriter, r *http.Request) {
	ok, err := s.Academic.RemoveCourseSubjectTeacher(r.Context(), urlParam(r, "id"), urlParam(r, "subjectID"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Assignment not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── preceptors ───────────────────────────────────────────────────────────────

func (s *Server) listCoursePreceptors(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Preceptors.ByCourse(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toCoursePreceptorDTO))
}

func (s *Server) assignCoursePreceptor(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Shift       string `json:"shift"`
		PreceptorID string `json:"preceptor_id"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	row, err := s.Preceptors.Assign(r.Context(), urlParam(r, "id"), b.Shift, b.PreceptorID)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toCoursePreceptorDTO(row))
}

func (s *Server) removeCoursePreceptor(w http.ResponseWriter, r *http.Request) {
	ok, err := s.Preceptors.Remove(r.Context(), urlParam(r, "id"), urlParam(r, "shift"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Assignment not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) listCoursePreceptorTemp(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Preceptors.TempByCourse(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toCoursePreceptorTempDTO))
}

func (s *Server) createCoursePreceptorTemp(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Shift       string  `json:"shift"`
		PreceptorID string  `json:"preceptor_id"`
		StartDate   string  `json:"start_date"`
		EndDate     string  `json:"end_date"`
		Reason      *string `json:"reason"`
		CreatedBy   string  `json:"created_by"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	row, err := s.Preceptors.CreateTemp(r.Context(), domain.CreateTempAssignmentParams{
		CourseID:    urlParam(r, "id"),
		Shift:       b.Shift,
		PreceptorID: b.PreceptorID,
		StartDate:   b.StartDate,
		EndDate:     b.EndDate,
		Reason:      b.Reason,
		CreatedBy:   b.CreatedBy,
	})
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toCoursePreceptorTempDTO(row))
}

func (s *Server) deleteCoursePreceptorTemp(w http.ResponseWriter, r *http.Request) {
	ok, err := s.Preceptors.DeleteTemp(r.Context(), urlParam(r, "assignmentID"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Assignment not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) listCourseWorkshopGroups(w http.ResponseWriter, r *http.Request) {
	rows, err := s.WorkshopGroup.ByCourse(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, func(g domain.WorkshopGroup) workshopGroupDTO {
		return workshopGroupDTO{g.ID, g.CourseID, g.GroupLabel}
	}))
}
