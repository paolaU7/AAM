package http

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

func (s *Server) mountDevice(r chi.Router) {
	r.Route("/device", func(r chi.Router) {
		r.Use(s.apiKeyAuth)
		r.Get("/health", s.deviceHealth)
		r.Post("/attendance", s.deviceAttendance)
		r.Post("/sync", s.deviceSync)
		r.Post("/secondary-auth", s.deviceSecondaryAuth)
	})
}

// deviceSecondaryAuth verifies a student's secondary credential (V1: a static
// QR) through the SecondaryAuthRegistry. Adding a new method later means
// registering another domain.SecondaryAuthenticator in main.go — this handler
// and the domain do not change.
func (s *Server) deviceSecondaryAuth(w http.ResponseWriter, r *http.Request) {
	var b struct {
		StudentID string `json:"student_id"`
		Method    string `json:"method"`
		Value     string `json:"value"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	if b.Method == "" {
		b.Method = "qr_static"
	}
	err := s.SecondaryAuth.Verify(r.Context(), b.StudentID, domain.SecondaryCredential{Method: b.Method, Value: b.Value})
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"verified": true, "method": b.Method})
}

func (s *Server) deviceHealth(w http.ResponseWriter, r *http.Request) {
	dev := deviceFromCtx(r)
	writeJSON(w, http.StatusOK, map[string]any{
		"status": "ok",
		"device": map[string]any{"id": dev.ID, "name": dev.Name},
	})
}

type deviceReadingBody struct {
	ID             string `json:"id"`      // ULID generated on the device
	TagUID         string `json:"tag_uid"` // NFC bracelet UID
	DeviceID       string `json:"device_id"`
	EntryTimestamp string `json:"entry_timestamp"`
	RecordedAt     string `json:"recorded_at"` // firmware's field name
}

func (b deviceReadingBody) toInput(fallbackDeviceID string) (domain.DeviceAttendanceInput, error) {
	ts := time.Now()
	raw := b.EntryTimestamp
	if raw == "" {
		raw = b.RecordedAt
	}
	if raw != "" {
		parsed, err := parseFlexibleTime(raw)
		if err != nil {
			return domain.DeviceAttendanceInput{}, err
		}
		ts = parsed
	}
	deviceID := b.DeviceID
	if deviceID == "" {
		deviceID = fallbackDeviceID
	}
	return domain.DeviceAttendanceInput{
		ID:             b.ID,
		TagUID:         b.TagUID,
		DeviceID:       deviceID,
		EntryTimestamp: ts,
	}, nil
}

func (s *Server) deviceAttendance(w http.ResponseWriter, r *http.Request) {
	dev := deviceFromCtx(r)
	var b deviceReadingBody
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	in, err := b.toInput(dev.ID)
	if err != nil {
		writeErr(w, err)
		return
	}
	stored, err := s.DeviceSync.IngestOne(r.Context(), in)
	if err != nil {
		writeErr(w, err)
		return
	}
	status := http.StatusOK // already present (deduplicated by ULID)
	if stored {
		status = http.StatusCreated
	}
	writeJSON(w, status, map[string]any{"id": in.ID, "stored": stored})
}

func (s *Server) deviceSync(w http.ResponseWriter, r *http.Request) {
	dev := deviceFromCtx(r)
	var b struct {
		Records []deviceReadingBody `json:"records"`
	}
	if err := decodeJSON(r, &b); err != nil {
		writeErr(w, err)
		return
	}
	inputs := make([]domain.DeviceAttendanceInput, 0, len(b.Records))
	for _, rec := range b.Records {
		in, err := rec.toInput(dev.ID)
		if err != nil {
			writeErr(w, err)
			return
		}
		inputs = append(inputs, in)
	}
	res, err := s.DeviceSync.IngestBatch(r.Context(), inputs)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"accepted":   nonNil(res.Accepted),
		"duplicated": nonNil(res.Duplicated),
		"rejected":   rejectionDTOs(res.Rejected),
	})
}

func nonNil(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}

func rejectionDTOs(in []domain.SyncRejection) []map[string]string {
	out := make([]map[string]string, 0, len(in))
	for _, r := range in {
		out = append(out, map[string]string{"id": r.ID, "reason": r.Reason})
	}
	return out
}
