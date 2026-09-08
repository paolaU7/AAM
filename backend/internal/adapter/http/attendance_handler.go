package http

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

func (s *Server) mountAttendance(r chi.Router) {
	r.Route("/attendance", func(r chi.Router) {
		r.Get("/", s.listRegistros)
		r.Get("/summary", s.getResumen)
		r.Post("/manual", s.registrarIngresoManual)
		r.Post("/{id}/early-departure", s.registrarRetiroAnticipado)
		r.Post("/{id}/mark-non-computable", s.marcarNoComputable)
	})
}

func (s *Server) listRegistros(w http.ResponseWriter, r *http.Request) {
	courseID := r.URL.Query().Get("course_id")
	date := r.URL.Query().Get("date")
	if courseID == "" || date == "" {
		detail(w, http.StatusBadRequest, "course_id y date son obligatorios.")
		return
	}
	rows, err := s.Attendance.ByCourseAndDate(r.Context(), courseID, date)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toRegistroDTO))
}

func (s *Server) getResumen(w http.ResponseWriter, r *http.Request) {
	date := r.URL.Query().Get("date")
	if date == "" {
		detail(w, http.StatusBadRequest, "date es obligatorio.")
		return
	}
	shift := r.URL.Query().Get("shift")

	var (
		resumen domain.ResumenAsistencia
		err     error
	)
	if shift != "" {
		resumen, err = s.Attendance.SummaryByShift(r.Context(), shift, date)
	} else {
		resumen, err = s.Attendance.DailySummary(r.Context(), date)
	}
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toResumenDTO(resumen))
}

func (s *Server) registrarIngresoManual(w http.ResponseWriter, r *http.Request) {
	var b struct {
		StudentID      string `json:"student_id"`
		CourseID       string `json:"course_id"`
		EntryTimestamp string `json:"entry_timestamp"`
		Status         string `json:"status"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	ts, err := parseFlexibleTime(b.EntryTimestamp)
	if err != nil {
		writeErr(w, err)
		return
	}
	reg, err := s.Attendance.RegisterManual(r.Context(), b.StudentID, b.CourseID, ts, b.Status)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toRegistroDTO(reg))
}

func (s *Server) registrarRetiroAnticipado(w http.ResponseWriter, r *http.Request) {
	var b struct {
		DepartureTime string `json:"departure_time"`
		Reason        string `json:"reason"`
		RegisteredBy  string `json:"registered_by"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	dt, err := parseFlexibleTime(b.DepartureTime)
	if err != nil {
		writeErr(w, err)
		return
	}
	reg, err := s.Attendance.RegisterEarlyDeparture(r.Context(), urlParam(r, "id"), dt, b.Reason, b.RegisteredBy)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toRegistroDTO(reg))
}

func (s *Server) marcarNoComputable(w http.ResponseWriter, r *http.Request) {
	reg, err := s.Attendance.MarkNonComputable(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toRegistroDTO(reg))
}

// parseFlexibleTime accepts the ISO-8601 shapes Dart's DateTime.toIso8601String
// can produce. Zoned values keep their offset; a zoneless value (Dart local
// DateTime) is read in the server's local time zone, not UTC, so it doesn't
// silently shift across a day boundary.
func parseFlexibleTime(s string) (time.Time, error) {
	zoned := []string{time.RFC3339Nano, time.RFC3339}
	for _, l := range zoned {
		if t, err := time.Parse(l, s); err == nil {
			return t, nil
		}
	}
	naive := []string{
		"2006-01-02T15:04:05.999999999",
		"2006-01-02T15:04:05",
		"2006-01-02T15:04",
	}
	for _, l := range naive {
		if t, err := time.ParseInLocation(l, s, time.Local); err == nil {
			return t, nil
		}
	}
	return time.Time{}, domain.NewDomainError("Fecha/hora inválida.", 400)
}
