package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

func (s *Server) mountWorkshopGroups(r chi.Router) {
	r.Get("/workshop-groups", s.listWorkshopGroups)
	r.Get("/workshop-groups/{id}/time-slots", s.listWorkshopGroupTimeSlots)
}

func (s *Server) listWorkshopGroups(w http.ResponseWriter, r *http.Request) {
	rows, err := s.WorkshopGroup.List(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, func(g domain.WorkshopGroup) workshopGroupDTO {
		return workshopGroupDTO{g.ID, g.CourseID, g.GroupLabel}
	}))
}

func (s *Server) listWorkshopGroupTimeSlots(w http.ResponseWriter, r *http.Request) {
	rows, err := s.TimeSlots.ByWorkshopGroup(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toTimeSlotDTO))
}

func (s *Server) mountSpecialties(r chi.Router) {
	r.Get("/specialties", s.listSpecialties)
	r.Get("/school-settings", s.getSchoolSettings)
}

func (s *Server) listSpecialties(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Specialties.List(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, func(sp domain.Specialty) specialtyDTO {
		return specialtyDTO{sp.ID, sp.Name, sp.IsBasicCycle}
	}))
}

func (s *Server) getSchoolSettings(w http.ResponseWriter, r *http.Request) {
	settings, err := s.Specialties.SchoolSettings(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, schoolSettingsDTO{settings.MaxGradeYear, settings.MaxDivision})
}

func (s *Server) mountNotifications(r chi.Router) {
	r.Get("/notifications", s.listNotifications)
}

func (s *Server) listNotifications(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Notifications.Alerts(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, func(n domain.Notification) notificationDTO {
		return notificationDTO{n.Type, n.Message}
	}))
}
