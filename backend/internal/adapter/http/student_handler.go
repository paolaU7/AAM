package http

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

func (s *Server) mountStudents(r chi.Router) {
	r.Route("/alumnos", func(r chi.Router) {
		r.Get("/", s.listAlumnos)
		r.Post("/", s.createAlumno)
		r.Post("/import-excel", s.importAlumnosExcel)
		r.Get("/{id}", s.getAlumno)
		r.Put("/{id}", s.updateAlumno)
		r.Post("/{id}/toggle-active", s.toggleAlumnoActive)
		r.Delete("/{id}", s.deleteAlumno)
	})
}

func (s *Server) listAlumnos(w http.ResponseWriter, r *http.Request) {
	list, err := s.Students.List(r.Context(), queryBool(r, "incluir_inactivos"))
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(list, toAlumnoDTO))
}

func (s *Server) getAlumno(w http.ResponseWriter, r *http.Request) {
	a, err := s.Students.Get(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if a == nil {
		detail(w, http.StatusNotFound, "Alumno no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toAlumnoDTO(*a))
}

type alumnoCreateBody struct {
	FirstName       string  `json:"first_name"`
	LastName        string  `json:"last_name"`
	NationalID      string  `json:"national_id"`
	CourseID        string  `json:"course_id"`
	WorkshopGroupID *string `json:"workshop_group_id"`
}

func (s *Server) createAlumno(w http.ResponseWriter, r *http.Request) {
	var b alumnoCreateBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	a, err := s.Students.CreateManual(r.Context(), domain.CrearAlumnoParams{
		FirstName:       b.FirstName,
		LastName:        b.LastName,
		NationalID:      b.NationalID,
		CourseID:        b.CourseID,
		WorkshopGroupID: b.WorkshopGroupID,
	})
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, toAlumnoDTO(*a))
}

type alumnoUpdateBody struct {
	Nombre          string  `json:"nombre"`
	Apellido        string  `json:"apellido"`
	DNI             string  `json:"dni"`
	CursoID         string  `json:"curso_id"`
	WorkshopGroupID *string `json:"workshop_group_id"`
}

func (s *Server) updateAlumno(w http.ResponseWriter, r *http.Request) {
	var b alumnoUpdateBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	result, err := s.Students.Update(r.Context(), urlParam(r, "id"), domain.Alumno{
		ID:              urlParam(r, "id"),
		Nombre:          b.Nombre,
		Apellido:        b.Apellido,
		DNI:             b.DNI,
		CursoID:         b.CursoID,
		WorkshopGroupID: b.WorkshopGroupID,
	})
	if err != nil {
		writeErr(w, err)
		return
	}
	if result == nil {
		detail(w, http.StatusNotFound, "Alumno no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toAlumnoDTO(*result))
}

func (s *Server) toggleAlumnoActive(w http.ResponseWriter, r *http.Request) {
	result, err := s.Students.ToggleActive(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if result == nil {
		detail(w, http.StatusNotFound, "Alumno no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toAlumnoDTO(*result))
}

// deleteAlumno hard-deletes — rejected (400) unless the student is already
// de baja, or (409) if it still has associated records.
func (s *Server) deleteAlumno(w http.ResponseWriter, r *http.Request) {
	ok, err := s.Students.Delete(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Alumno no encontrado")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type importReportDTO struct {
	CursoID    string              `json:"curso_id"`
	TotalFilas int                 `json:"total_filas"`
	Creados    int                 `json:"creados"`
	Errores    []importRowErrorDTO `json:"errores"`
}

type importRowErrorDTO struct {
	Fila   int    `json:"fila"`
	Motivo string `json:"motivo"`
}

func (s *Server) importAlumnosExcel(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(16 << 20); err != nil {
		detail(w, http.StatusBadRequest, "No se pudo leer el formulario.")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		detail(w, http.StatusBadRequest, "Falta el archivo.")
		return
	}
	defer file.Close()

	name := strings.ToLower(header.Filename)
	if !strings.HasSuffix(name, ".xlsx") && !strings.HasSuffix(name, ".xlsm") {
		detail(w, http.StatusBadRequest, "El archivo debe ser un Excel (.xlsx).")
		return
	}

	academicYear, gradeYear, division, rows, perr := parseStudentsWorkbook(file)
	if perr != nil {
		writeErr(w, perr)
		return
	}

	report, err := s.StudentImport.Import(r.Context(), academicYear, gradeYear, division, rows)
	if err != nil {
		writeErr(w, err)
		return
	}

	errs := make([]importRowErrorDTO, 0, len(report.Errores))
	for _, e := range report.Errores {
		errs = append(errs, importRowErrorDTO{Fila: e.Fila, Motivo: e.Motivo})
	}
	writeJSON(w, http.StatusOK, importReportDTO{
		CursoID:    report.CursoID,
		TotalFilas: report.TotalFilas,
		Creados:    len(report.Creados),
		Errores:    errs,
	})
}
