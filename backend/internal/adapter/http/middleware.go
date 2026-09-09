package http

import (
	"context"
	"net/http"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

type ctxKey string

const (
	ctxDevice ctxKey = "device"
	ctxUserID ctxKey = "userID"
	ctxRole   ctxKey = "role"
)

// apiKeyAuth is the device (ESP32) authentication middleware: it validates the
// X-API-Key header against devices.api_key_hash and stashes the resolved
// device in the request context. It only protects the /device/* routes.
func (s *Server) apiKeyAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get("X-API-Key")
		if key == "" {
			key = strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		}
		dev, err := s.Devices.FindByAPIKey(r.Context(), key)
		if err != nil {
			writeErr(w, err)
			return
		}
		if dev == nil {
			detail(w, http.StatusUnauthorized, "API Key inválida o dispositivo inactivo.")
			return
		}
		_ = s.Devices.TouchLastSeen(r.Context(), dev.ID)
		ctx := context.WithValue(r.Context(), ctxDevice, dev)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func deviceFromCtx(r *http.Request) *domain.Device {
	d, _ := r.Context().Value(ctxDevice).(*domain.Device)
	return d
}

// requireSession parses the bearer token and stashes the user id + role. It is
// wired but not yet applied to the parity routes (that would break the current
// Flutter app, which has no login flow) — kept ready for role-gating.
func (s *Server) requireSession(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if raw == "" {
			detail(w, http.StatusUnauthorized, "Falta el token de sesión.")
			return
		}
		userID, role, err := s.Tokens.Parse(raw)
		if err != nil {
			writeErr(w, err)
			return
		}
		ctx := context.WithValue(r.Context(), ctxUserID, userID)
		ctx = context.WithValue(ctx, ctxRole, role)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// requirePrincipal is the placeholder gate for the Dirección → Configuración
// routes. In the product these are dirección-only, but the Flutter panel has no
// login flow yet, so — like the parity routes — this currently lets every
// request through. It exists as a single named seam: once panel auth ships,
// change the body to
//
//	return s.requireSession(s.requireRole(domain.RolPrincipal)(next))
//
// and every /config route is closed off at once.
func (s *Server) requirePrincipal(next http.Handler) http.Handler {
	return next
}

// requireRole builds a middleware that enforces one of the given roles. Compose
// after requireSession.
func (s *Server) requireRole(roles ...domain.RolUsuario) func(http.Handler) http.Handler {
	allowed := make(map[domain.RolUsuario]bool, len(roles))
	for _, r := range roles {
		allowed[r] = true
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			role, _ := r.Context().Value(ctxRole).(domain.RolUsuario)
			if !allowed[role] {
				detail(w, http.StatusForbidden, "No tenés permiso para esta acción.")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
