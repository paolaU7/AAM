package postgres

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type TimeSlotRepo struct{ pool *pgxpool.Pool }

func NewTimeSlotRepo(pool *pgxpool.Pool) *TimeSlotRepo { return &TimeSlotRepo{pool} }

const timeSlotSelect = `
	SELECT id, shift::text, activity_type::text, day_of_week,
	       start_time::text, end_time::text, late_tolerance_minutes,
	       is_active, course_id, workshop_group_id
	FROM time_slots`

func scanTimeSlot(row pgx.Row) (domain.TimeSlot, error) {
	var t domain.TimeSlot
	err := row.Scan(&t.ID, &t.Shift, &t.ActivityType, &t.DayOfWeek,
		&t.StartTime, &t.EndTime, &t.LateToleranceMinutes,
		&t.IsActive, &t.CourseID, &t.WorkshopGroupID)
	return t, err
}

func (r *TimeSlotRepo) collect(ctx context.Context, where string, args ...any) ([]domain.TimeSlot, error) {
	rows, err := r.pool.Query(ctx, timeSlotSelect+" "+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.TimeSlot
	for rows.Next() {
		t, err := scanTimeSlot(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r *TimeSlotRepo) GetByCourse(ctx context.Context, courseID string) ([]domain.TimeSlot, error) {
	return r.collect(ctx, "WHERE course_id = $1 AND is_active = true", courseID)
}

func (r *TimeSlotRepo) GetByWorkshopGroup(ctx context.Context, workshopGroupID string) ([]domain.TimeSlot, error) {
	return r.collect(ctx, "WHERE workshop_group_id = $1 AND is_active = true", workshopGroupID)
}

func (r *TimeSlotRepo) Create(ctx context.Context, p domain.CreateTimeSlotParams) (domain.TimeSlot, error) {
	var id string
	err := r.pool.QueryRow(ctx, `
		INSERT INTO time_slots
		    (course_id, workshop_group_id, shift, activity_type, day_of_week,
		     start_time, end_time, late_tolerance_minutes)
		VALUES ($1, $2, $3::shift_type, $4::activity_type, $5, $6::time, $7::time, $8)
		RETURNING id`,
		derefStr(p.CourseID), derefStr(p.WorkshopGroupID), p.Shift, p.ActivityType, p.DayOfWeek,
		p.StartTime, p.EndTime, p.LateToleranceMinutes).Scan(&id)
	if err != nil {
		return domain.TimeSlot{}, mapDBError(err, "No se pudo crear la franja horaria.")
	}
	t, err := scanTimeSlot(r.pool.QueryRow(ctx, timeSlotSelect+" WHERE id = $1", id))
	return t, err
}

func (r *TimeSlotRepo) Update(ctx context.Context, id string, p domain.CreateTimeSlotParams) (domain.TimeSlot, error) {
	tag, err := r.pool.Exec(ctx, `
		UPDATE time_slots
		SET shift = $2::shift_type, activity_type = $3::activity_type, day_of_week = $4,
		    start_time = $5::time, end_time = $6::time, late_tolerance_minutes = $7
		WHERE id = $1`,
		id, p.Shift, p.ActivityType, p.DayOfWeek, p.StartTime, p.EndTime, p.LateToleranceMinutes)
	if err != nil {
		return domain.TimeSlot{}, mapDBError(err, "No se pudo actualizar la franja horaria.")
	}
	if tag.RowsAffected() == 0 {
		return domain.TimeSlot{}, mapDBError(nil, "Franja horaria no encontrada.")
	}
	t, err := scanTimeSlot(r.pool.QueryRow(ctx, timeSlotSelect+" WHERE id = $1", id))
	return t, err
}

func (r *TimeSlotRepo) Delete(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM time_slots WHERE id = $1`, id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// Disable soft-deletes the time slot by setting is_active = false.
func (r *TimeSlotRepo) Disable(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `UPDATE time_slots SET is_active = false WHERE id = $1`, id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}
