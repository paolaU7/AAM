package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

func (s *Server) mountAcademic(r chi.Router) {
	r.Get("/subjects", s.listSubjects)
	r.Post("/subjects", s.createSubject)
	r.Get("/subjects/{id}/applicability", s.listSubjectApplicability)
	r.Post("/subjects/{id}/applicability", s.addSubjectApplicability)
	r.Delete("/subjects/{id}/applicability/{applicabilityID}", s.removeSubjectApplicability)

	r.Get("/teachers", s.listTeachers)
	r.Post("/teachers", s.createTeacher)
	r.Get("/teachers/{id}/assignments", s.listTeacherAssignments)
}

func (s *Server) listSubjects(w http.ResponseWriter, r *http.Request) {
	var gradeYear *int
	if v, ok, err := queryInt(r, "grade_year"); err != nil {
		detail(w, http.StatusBadRequest, "grade_year inválido.")
		return
	} else if ok {
		gradeYear = &v
	}
	var specialtyID *string
	if v := r.URL.Query().Get("specialty_id"); v != "" {
		specialtyID = &v
	}
	rows, err := s.Academic.ListSubjects(r.Context(), gradeYear, specialtyID)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toSubjectDTO))
}

func (s *Server) createSubject(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Name        string `json:"name"`
		SubjectType string `json:"subject_type"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	sub, err := s.Academic.CreateSubject(r.Context(), b.Name, b.SubjectType)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toSubjectDTO(sub))
}

func (s *Server) listSubjectApplicability(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Academic.SubjectApplicability(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toApplicabilityDTO))
}

func (s *Server) addSubjectApplicability(w http.ResponseWriter, r *http.Request) {
	var b struct {
		GradeYear   int    `json:"grade_year"`
		SpecialtyID string `json:"specialty_id"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	row, err := s.Academic.AddApplicability(r.Context(), urlParam(r, "id"), b.GradeYear, b.SpecialtyID)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toApplicabilityDTO(row))
}

func (s *Server) removeSubjectApplicability(w http.ResponseWriter, r *http.Request) {
	ok, err := s.Academic.RemoveApplicability(r.Context(), urlParam(r, "applicabilityID"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "No encontrado")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) listTeachers(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Academic.ListTeachers(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toTeacherDTO))
}

func (s *Server) createTeacher(w http.ResponseWriter, r *http.Request) {
	var b struct {
		FullName string  `json:"full_name"`
		Email    *string `json:"email"`
		Phone    *string `json:"phone"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	t, err := s.Academic.CreateTeacher(r.Context(), b.FullName, b.Email, b.Phone)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toTeacherDTO(t))
}

func (s *Server) listTeacherAssignments(w http.ResponseWriter, r *http.Request) {
	rows, err := s.Academic.TeacherAssignments(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toSubjectTeacherDTO))
}
