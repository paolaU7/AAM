// Package http is the REST adapter: chi handlers + DTOs. It is endpoint-,
// method- and JSON-shape-compatible with the previous FastAPI backend so the
// existing Flutter app keeps working unchanged, including the {"detail": "..."}
// error envelope and the Spanish field names on the student/user DTOs.
package http

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// writeJSON encodes v with the given status.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if v == nil {
		return
	}
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("http: encode response: %v", err)
	}
}

// writeErr maps an error to the {"detail": "..."} envelope. A *domain.DomainError
// carries its own status; anything else is a 500 with a generic message (the
// real error is logged).
func writeErr(w http.ResponseWriter, err error) {
	var de *domain.DomainError
	if errors.As(err, &de) {
		writeJSON(w, de.StatusCode, map[string]string{"detail": de.Message})
		return
	}
	log.Printf("http: unhandled error: %v", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"detail": "Error interno del servidor."})
}

// detail is a shorthand for an ad-hoc {"detail": msg} at a status.
func detail(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"detail": msg})
}

// decodeJSON reads the request body into dst, returning a 400 DomainError on
// malformed JSON.
func decodeJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(dst); err != nil && !errors.Is(err, io.EOF) {
		return domain.NewDomainError("Cuerpo de la solicitud inválido.", 400)
	}
	return nil
}
