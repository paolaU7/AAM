package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// Dirección → "Configuración" endpoints. All under /config, all wrapped by the
// requirePrincipal placeholder in Router(). Postgres errors are mapped in the
// repos (23505 → 409, trigger P0001 / FK 23503 / others → 400 with the DB
// message) and flow through writeErr.
func (s *Server) mountConfig(r chi.Router) {
	r.Route("/config", func(r chi.Router) {
		// General
		r.Get("/school-settings", s.getConfigSchoolSettings)
		r.Put("/school-settings", s.putConfigSchoolSettings)
		r.Get("/shifts", s.listShifts)
		r.Put("/shifts/{shift}", s.renameShift)
		r.Get("/shift-breaks", s.listShiftBreaks)
		r.Post("/shift-breaks", s.createShiftBreak)
		r.Delete("/shift-breaks/{id}", s.deleteShiftBreak)

		// Cursos (academic structure)
		r.Get("/courses/structure", s.getCoursesStructure)
		r.Put("/courses/structure", s.putCoursesStructure)

		// Dispositivos
		r.Get("/entry-points", s.listEntryPoints)
		r.Post("/entry-points", s.createEntryPoint)
		r.Put("/entry-points/{id}", s.updateEntryPoint)
		r.Delete("/entry-points/{id}", s.deleteEntryPoint)
		r.Get("/devices", s.listConfigDevices)
		r.Post("/devices", s.createConfigDevice)
		r.Post("/devices/{id}/revoke", s.revokeConfigDevice)
	})
}

// ── General: school settings (alerts + lunch window) ───────────────────────

func (s *Server) getConfigSchoolSettings(w http.ResponseWriter, r *http.Request) {
	settings, err := s.SchoolSettings.Get(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toConfigSchoolSettingsDTO(settings))
}

func (s *Server) putConfigSchoolSettings(w http.ResponseWriter, r *http.Request) {
	var b struct {
		LunchStart                        string `json:"lunch_start"`
		LunchStartFifthModule             string `json:"lunch_start_fifth_module"`
		LunchEnd                          string `json:"lunch_end"`
		ConsecutiveAbsencesAlertThreshold int    `json:"consecutive_absences_alert_threshold"`
		PreceptorTempAssignmentAlertDays  int    `json:"preceptor_temp_assignment_alert_days"`
		ScheduleExceptionAlertDays        int    `json:"schedule_exception_alert_days"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	updated, err := s.SchoolSettings.Update(r.Context(), domain.SchoolSettings{
		LunchStart:                        b.LunchStart,
		LunchStartFifthModule:             b.LunchStartFifthModule,
		LunchEnd:                          b.LunchEnd,
		ConsecutiveAbsencesAlertThreshold: b.ConsecutiveAbsencesAlertThreshold,
		PreceptorTempAssignmentAlertDays:  b.PreceptorTempAssignmentAlertDays,
		ScheduleExceptionAlertDays:        b.ScheduleExceptionAlertDays,
	})
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toConfigSchoolSettingsDTO(updated))
}

// ── General: shift labels ─────────────────────────────────────────────────

func (s *Server) listShifts(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Shifts.List(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toShiftConfigDTO))
}

func (s *Server) renameShift(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Label string `json:"label"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	sh, err := s.Shifts.Rename(r.Context(), urlParam(r, "shift"), b.Label)
	if err != nil {
		writeErr(w, err)
		return
	}
	if sh == nil {
		detail(w, http.StatusNotFound, "Turno no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toShiftConfigDTO(*sh))
}

// ── General: shift breaks (recreos) ───────────────────────────────────────

func (s *Server) listShiftBreaks(w http.ResponseWriter, r *http.Request) {
	shift := r.URL.Query().Get("shift")
	if shift == "" {
		detail(w, http.StatusBadRequest, "Falta el parámetro shift.")
		return
	}
	rows, err := s.ShiftBreaks.ListByShift(r.Context(), shift)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toShiftBreakDTO))
}

func (s *Server) createShiftBreak(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Shift     string `json:"shift"`
		Label     string `json:"label"`
		StartTime string `json:"start_time"`
		EndTime   string `json:"end_time"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	br, err := s.ShiftBreaks.Create(r.Context(), b.Shift, b.Label, b.StartTime, b.EndTime)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toShiftBreakDTO(br))
}

func (s *Server) deleteShiftBreak(w http.ResponseWriter, r *http.Request) {
	ok, err := s.ShiftBreaks.Delete(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Recreo no encontrado")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Cursos: academic structure ───────────────────────────────────────────

func (s *Server) getCoursesStructure(w http.ResponseWriter, r *http.Request) {
	st, err := s.CourseStructure.Get(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toCoursesStructureDTO(st))
}

func (s *Server) putCoursesStructure(w http.ResponseWriter, r *http.Request) {
	var b struct {
		CurrentAcademicYear int `json:"current_academic_year"`
		MaxGradeYear        int `json:"max_grade_year"`
		Years               []struct {
			GradeYear     int `json:"grade_year"`
			DivisionCount int `json:"division_count"`
			Divisions     []struct {
				Division           int `json:"division"`
				WorkshopGroupCount int `json:"workshop_group_count"`
			} `json:"divisions"`
		} `json:"years"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	in := domain.CoursesStructure{CurrentAcademicYear: b.CurrentAcademicYear, MaxGradeYear: b.MaxGradeYear}
	for _, y := range b.Years {
		yd := domain.YearDivisionStructure{GradeYear: y.GradeYear, DivisionCount: y.DivisionCount}
		for _, d := range y.Divisions {
			yd.Divisions = append(yd.Divisions, domain.DivisionStructure{Division: d.Division, WorkshopGroupCount: d.WorkshopGroupCount})
		}
		in.Years = append(in.Years, yd)
	}
	out, err := s.CourseStructure.Replace(r.Context(), in)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, toCoursesStructureDTO(out))
}

// ── Dispositivos: entry points ───────────────────────────────────────────

type entryPointBody struct {
	Name     string  `json:"name"`
	Location *string `json:"location"`
}

func (s *Server) listEntryPoints(w http.ResponseWriter, r *http.Request) {
	rows, err := s.DeviceConfig.ListEntryPoints(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toEntryPointDTO))
}

func (s *Server) createEntryPoint(w http.ResponseWriter, r *http.Request) {
	var b entryPointBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	e, err := s.DeviceConfig.CreateEntryPoint(r.Context(), b.Name, b.Location)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toEntryPointDTO(e))
}

func (s *Server) updateEntryPoint(w http.ResponseWriter, r *http.Request) {
	var b entryPointBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	e, err := s.DeviceConfig.UpdateEntryPoint(r.Context(), urlParam(r, "id"), b.Name, b.Location)
	if err != nil {
		writeErr(w, err)
		return
	}
	if e == nil {
		detail(w, http.StatusNotFound, "Punto de acceso no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toEntryPointDTO(*e))
}

func (s *Server) deleteEntryPoint(w http.ResponseWriter, r *http.Request) {
	ok, err := s.DeviceConfig.DeleteEntryPoint(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Punto de acceso no encontrado")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Dispositivos: devices ────────────────────────────────────────────────

func (s *Server) listConfigDevices(w http.ResponseWriter, r *http.Request) {
	rows, err := s.DeviceConfig.ListDevices(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toDeviceConfigDTO))
}

func (s *Server) createConfigDevice(w http.ResponseWriter, r *http.Request) {
	var b struct {
		EntryPointID string `json:"entry_point_id"`
		Name         string `json:"name"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	created, err := s.DeviceConfig.CreateDevice(r.Context(), b.EntryPointID, b.Name)
	if err != nil {
		writeErr(w, err)
		return
	}
	// api_key is included here and NOWHERE else.
	writeJSON(w, http.StatusCreated, toDeviceCreatedDTO(created))
}

func (s *Server) revokeConfigDevice(w http.ResponseWriter, r *http.Request) {
	if err := s.DeviceConfig.RevokeDevice(r.Context(), urlParam(r, "id")); err != nil {
		writeErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
