package postgres

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// ── course_preceptors (permanent) ────────────────────────────────────────────

type CoursePreceptorRepo struct{ pool *pgxpool.Pool }

func NewCoursePreceptorRepo(pool *pgxpool.Pool) *CoursePreceptorRepo {
	return &CoursePreceptorRepo{pool}
}

const coursePreceptorSelect = `
	SELECT cp.id, cp.course_id, cp.shift::text, cp.preceptor_id, u.full_name, cp.day_of_week
	FROM course_preceptors cp
	JOIN users u ON u.id = cp.preceptor_id`

func scanCoursePreceptor(row pgx.Row) (domain.CoursePreceptor, error) {
	var c domain.CoursePreceptor
	err := row.Scan(&c.ID, &c.CourseID, &c.Shift, &c.PreceptorID, &c.PreceptorName, &c.DayOfWeek)
	return c, err
}

func (r *CoursePreceptorRepo) GetByCourse(ctx context.Context, courseID string) ([]domain.CoursePreceptor, error) {
	rows, err := r.pool.Query(ctx, coursePreceptorSelect+" WHERE cp.course_id = $1 ORDER BY cp.shift, cp.day_of_week", courseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.CoursePreceptor
	for rows.Next() {
		c, err := scanCoursePreceptor(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *CoursePreceptorRepo) Assign(ctx context.Context, courseID, shift, preceptorID string, dayOfWeek int) (domain.CoursePreceptor, error) {
	var id string
	err := r.pool.QueryRow(ctx, `
		INSERT INTO course_preceptors (course_id, shift, preceptor_id, day_of_week)
		VALUES ($1, $2::shift_type, $3, $4)
		ON CONFLICT (course_id, shift, day_of_week) DO UPDATE SET preceptor_id = EXCLUDED.preceptor_id
		RETURNING id`,
		courseID, shift, preceptorID, dayOfWeek).Scan(&id)
	if err != nil {
		return domain.CoursePreceptor{}, mapDBError(err, "No se pudo asignar el preceptor.")
	}
	return scanCoursePreceptor(r.pool.QueryRow(ctx,
		coursePreceptorSelect+" WHERE cp.id = $1", id))
}

func (r *CoursePreceptorRepo) Remove(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM course_preceptors WHERE id = $1`, id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// ── course_preceptor_temp_assignments ────────────────────────────────────────

type CoursePreceptorTempAssignmentRepo struct{ pool *pgxpool.Pool }

func NewCoursePreceptorTempAssignmentRepo(pool *pgxpool.Pool) *CoursePreceptorTempAssignmentRepo {
	return &CoursePreceptorTempAssignmentRepo{pool}
}

const tempAssignmentSelect = `
	SELECT t.id, t.course_id, t.shift::text, t.preceptor_id, u.full_name,
	       t.start_date::text, t.end_date::text, t.reason
	FROM course_preceptor_temp_assignments t
	JOIN users u ON u.id = t.preceptor_id`

func scanTempAssignment(row pgx.Row) (domain.CoursePreceptorTempAssignment, error) {
	var a domain.CoursePreceptorTempAssignment
	err := row.Scan(&a.ID, &a.CourseID, &a.Shift, &a.PreceptorID, &a.PreceptorName,
		&a.StartDate, &a.EndDate, &a.Reason)
	return a, err
}

func (r *CoursePreceptorTempAssignmentRepo) GetByCourse(ctx context.Context, courseID string) ([]domain.CoursePreceptorTempAssignment, error) {
	rows, err := r.pool.Query(ctx, tempAssignmentSelect+" WHERE t.course_id = $1 ORDER BY t.start_date DESC", courseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.CoursePreceptorTempAssignment
	for rows.Next() {
		a, err := scanTempAssignment(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r *CoursePreceptorTempAssignmentRepo) Create(ctx context.Context, p domain.CreateTempAssignmentParams) (domain.CoursePreceptorTempAssignment, error) {
	var id string
	err := r.pool.QueryRow(ctx, `
		INSERT INTO course_preceptor_temp_assignments
		    (course_id, shift, preceptor_id, start_date, end_date, reason, created_by)
		VALUES ($1, $2::shift_type, $3, $4::date, $5::date, $6, $7)
		RETURNING id`,
		p.CourseID, p.Shift, p.PreceptorID, p.StartDate, p.EndDate, derefStr(p.Reason), p.CreatedBy).Scan(&id)
	if err != nil {
		return domain.CoursePreceptorTempAssignment{}, mapDBError(err, "No se pudo crear el reemplazo temporal.")
	}
	return scanTempAssignment(r.pool.QueryRow(ctx, tempAssignmentSelect+" WHERE t.id = $1", id))
}

func (r *CoursePreceptorTempAssignmentRepo) Delete(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM course_preceptor_temp_assignments WHERE id = $1`, id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}
