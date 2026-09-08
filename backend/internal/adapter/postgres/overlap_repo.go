package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

// OverlapDetector is V1 scaffolding for the automatic non-computable-absence
// rule for repeating students (recursantes): when a repeating student's absence
// from the current shift coincides with a subject they are re-taking from a
// previous year, that absence must not count against their RITE rate.
//
// The automatic detection needs a source of "which subjects is this student
// re-taking and on what schedule" (a repeating_subjects / repeating_student_links
// table). That data is not wired into the current model, so this implementation
// always reports false — the preceptor handles it manually via
// POST /attendance/{id}/mark-non-computable, exactly as today. When the data
// source lands, implement the time_slots overlap check here without touching
// the domain or the use cases.
type OverlapDetector struct{ pool *pgxpool.Pool }

func NewOverlapDetector(pool *pgxpool.Pool) *OverlapDetector { return &OverlapDetector{pool} }

func (d *OverlapDetector) IsNonComputable(ctx context.Context, studentID, courseID, shift, date string) (bool, error) {
	return false, nil
}
