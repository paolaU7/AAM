// Package app holds the use cases of AAM — the business orchestration layer.
// It depends only on internal/domain (entities + ports) and never on the web
// framework or the database driver. It mirrors app/domain/usecases/*.py of the
// previous Python backend, one service struct per area.
package app
