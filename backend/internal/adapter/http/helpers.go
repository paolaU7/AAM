package http

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// mapList converts a domain slice to a DTO slice, guaranteeing a non-nil result
// so list endpoints serialise as [] (never null) — matching FastAPI.
func mapList[T any, R any](in []T, f func(T) R) []R {
	out := make([]R, 0, len(in))
	for _, x := range in {
		out = append(out, f(x))
	}
	return out
}

func urlParam(r *http.Request, key string) string { return chi.URLParam(r, key) }

// queryInt parses an optional integer query param. ok is false when absent.
func queryInt(r *http.Request, key string) (val int, ok bool, err error) {
	s := r.URL.Query().Get(key)
	if s == "" {
		return 0, false, nil
	}
	v, err := strconv.Atoi(s)
	if err != nil {
		return 0, false, err
	}
	return v, true, nil
}

func queryBool(r *http.Request, key string) bool {
	v := r.URL.Query().Get(key)
	return v == "true" || v == "1" || v == "True"
}
