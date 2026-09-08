package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

func (s *Server) mountUsers(r chi.Router) {
	r.Route("/users", func(r chi.Router) {
		r.Get("/", s.listUsers)
		r.Post("/", s.createUser)
		r.Post("/{id}/toggle-active", s.toggleUserActive)
		r.Post("/{id}/reset-password", s.resetUserPassword)
		r.Put("/{id}", s.updateUser)
		r.Delete("/{id}", s.deleteUser)
	})
}

func (s *Server) listUsers(w http.ResponseWriter, r *http.Request) {
	list, err := s.Users.List(r.Context())
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, mapList(list, toUserDTO))
}

type userBody struct {
	Nombre   string `json:"nombre"`
	Apellido string `json:"apellido"`
	Rol      string `json:"rol"`
}

func (s *Server) createUser(w http.ResponseWriter, r *http.Request) {
	var b userBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	rol, err := domain.ParseRol(b.Rol)
	if err != nil {
		writeErr(w, err)
		return
	}
	res, err := s.Users.Create(r.Context(), b.Nombre, b.Apellido, rol)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"usuario":           toUserDTO(res.Usuario),
		"password_temporal": res.TemporaryPassword,
	})
}

func (s *Server) toggleUserActive(w http.ResponseWriter, r *http.Request) {
	u, err := s.Users.ToggleActive(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if u == nil {
		detail(w, http.StatusNotFound, "Usuario no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toUserDTO(*u))
}

func (s *Server) resetUserPassword(w http.ResponseWriter, r *http.Request) {
	pw, err := s.Users.ResetPassword(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if pw == nil {
		detail(w, http.StatusNotFound, "Usuario no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"password_temporal": *pw})
}

func (s *Server) updateUser(w http.ResponseWriter, r *http.Request) {
	var b userBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	rol, err := domain.ParseRol(b.Rol)
	if err != nil {
		writeErr(w, err)
		return
	}
	u, err := s.Users.Update(r.Context(), urlParam(r, "id"), b.Nombre, b.Apellido, rol)
	if err != nil {
		writeErr(w, err)
		return
	}
	if u == nil {
		detail(w, http.StatusNotFound, "Usuario no encontrado")
		return
	}
	writeJSON(w, http.StatusOK, toUserDTO(*u))
}

func (s *Server) deleteUser(w http.ResponseWriter, r *http.Request) {
	ok, err := s.Users.Delete(r.Context(), urlParam(r, "id"))
	if err != nil {
		writeErr(w, err)
		return
	}
	if !ok {
		detail(w, http.StatusNotFound, "Usuario no encontrado")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
