package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

func (s *Server) mountAuth(r chi.Router) {
	r.Post("/auth/login", s.login)
}

// login is the (new) panel authentication endpoint. It is additive: the
// existing routes are not yet gated behind it, so the current Flutter app is
// unaffected. RequireRole middleware is available for when access control is
// switched on.
func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	var b struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	sess, err := s.Auth.Login(r.Context(), b.Username, b.Password)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token": sess.Token,
		"user":  toUserDTO(sess.User),
	})
}
