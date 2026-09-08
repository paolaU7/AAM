package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type WorkshopGroupRepo struct{ pool *pgxpool.Pool }

func NewWorkshopGroupRepo(pool *pgxpool.Pool) *WorkshopGroupRepo { return &WorkshopGroupRepo{pool} }

func (r *WorkshopGroupRepo) query(ctx context.Context, where string, args ...any) ([]domain.WorkshopGroup, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, course_id, group_label FROM workshop_groups `+where+` ORDER BY group_label`, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.WorkshopGroup
	for rows.Next() {
		var w domain.WorkshopGroup
		if err := rows.Scan(&w.ID, &w.CourseID, &w.GroupLabel); err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	return out, rows.Err()
}

func (r *WorkshopGroupRepo) GetAll(ctx context.Context) ([]domain.WorkshopGroup, error) {
	return r.query(ctx, "")
}

func (r *WorkshopGroupRepo) GetByCourse(ctx context.Context, courseID string) ([]domain.WorkshopGroup, error) {
	return r.query(ctx, "WHERE course_id = $1", courseID)
}
