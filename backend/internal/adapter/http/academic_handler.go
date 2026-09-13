package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

func (s *Server) mountAcademic(r chi.Router) {
	r.Get("/subjects", s.listSubjects)
	r.Post("/subjects", s.createSubject)
	r.Put("/subjects/{id}", s.updateSubjectShortCode)
	r.Put("/subjects/{id}/details", s.updateSubjectDetails)
	r.Post("/subjects/{id}/toggle-active", s.toggleSubjectActive)
	r.Delete("/subjects/{id}", s.deleteSubject)
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
	writeJSON(w, http.StatusOK, mapList(rows, toSubjectWithApplicabilityDTO))
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

// updateSubjectShortCode edits a subject's short_code by hand. An empty
// short_code in the body reverts it to automático (recomputed from the
// current name + applicability).
func (s *Server) updateSubjectShortCode(w http.ResponseWriter, r *http.Request) {
	var b struct {
		ShortCode string `json:"short_code"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	sub, err := s.Academic.UpdateSubjectShortCode(r.Context(), urlParam(r, "id"), b.ShortCode)
	if err != nil {
		writeErr(w, err)
		return
	}
	if sub == nil {
		detail(w, http.StatusNotFound, "No encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toSubjectDTO(*sub))
}

// updateSubjectDetails edits a subject's name + type together (the pencil in
// the Materias screen).
func (s *Server) updateSubjectDetails(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Name        string `json:"name"`
		SubjectType string `json:"subject_type"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	sub, err := s.Academic.UpdateSubjectDetails(r.Context(), urlParam(r, "id"), b.Name, b.SubjectType)
	if err != nil {
		writeErr(w, err)
		return
	}
	if sub == nil {
		detail(w, http.StatusNotFound, "No encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toSubjectDTO(*sub))
}

// toggleSubjectActive flips is_active (dar de baja / dar de alta).
func (s *Server) toggleSubjectActive(w http.ResponseWriter, r *http.Request) {
	sub, err := s.Academic.ToggleSubjectActive(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if sub == nil {
		detail(w, http.StatusNotFound, "No encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toSubjectDTO(*sub))
}

// deleteSubject hard-deletes — the service/repo enforce that it's already
// dada de baja and has no associated courses/teachers.
func (s *Server) deleteSubject(w http.ResponseWriter, r *http.Request) {
	ok, err := s.Academic.DeleteSubject(r.Context(), urlParam(r, "id"))
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
	var subjectID *string
	if v := r.URL.Query().Get("subject_id"); v != "" {
		subjectID = &v
	}
	rows, err := s.Academic.ListTeachers(r.Context(), subjectID)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(rows, toTeacherWithAssignmentsDTO))
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
