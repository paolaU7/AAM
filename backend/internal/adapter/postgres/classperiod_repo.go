package postgres

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type ClassPeriodRepo struct{ pool *pgxpool.Pool }

func NewClassPeriodRepo(pool *pgxpool.Pool) *ClassPeriodRepo { return &ClassPeriodRepo{pool} }

const classPeriodSelect = `
	SELECT cp.id, cp.course_id, cp.workshop_group_id, cp.day_of_week, cp.shift::text,
	       cp.period_order, cp.period_type::text, cp.start_time::text, cp.end_time::text,
	       cp.is_fifth_module, cp.subject_id, sub.name, cp.teacher_id, t.full_name
	FROM class_periods cp
	LEFT JOIN subjects sub ON sub.id = cp.subject_id
	LEFT JOIN teachers t ON t.id = cp.teacher_id`

func scanClassPeriod(row pgx.Row) (domain.ClassPeriod, error) {
	var p domain.ClassPeriod
	err := row.Scan(&p.ID, &p.CourseID, &p.WorkshopGroupID, &p.DayOfWeek, &p.Shift,
		&p.PeriodOrder, &p.PeriodType, &p.StartTime, &p.EndTime,
		&p.IsFifthModule, &p.SubjectID, &p.SubjectName, &p.TeacherID, &p.TeacherName)
	return p, err
}

func (r *ClassPeriodRepo) GetByCourse(ctx context.Context, courseID string) ([]domain.ClassPeriod, error) {
	rows, err := r.pool.Query(ctx,
		classPeriodSelect+" WHERE cp.course_id = $1 ORDER BY cp.day_of_week, cp.shift, cp.period_order",
		courseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.ClassPeriod
	for rows.Next() {
		p, err := scanClassPeriod(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *ClassPeriodRepo) Create(ctx context.Context, p domain.CreateClassPeriodParams) (domain.ClassPeriod, error) {
	// period_order is computed as the next number within the scope: curricular
	// -> (course_id, day, shift); workshop -> (workshop_group_id, day, shift).
	// Mirrors the two partial unique indexes on class_periods.
	var scope string
	var scopeArg any
	if p.WorkshopGroupID != nil && *p.WorkshopGroupID != "" {
		scope = "workshop_group_id = $5"
		scopeArg = *p.WorkshopGroupID
	} else {
		scope = "course_id = $5 AND workshop_group_id IS NULL"
		scopeArg = p.CourseID
	}

	var id string
	err := r.pool.QueryRow(ctx, `
		INSERT INTO class_periods
		    (course_id, workshop_group_id, day_of_week, shift, period_order,
		     period_type, subject_id, teacher_id, start_time, end_time, is_fifth_module)
		VALUES ($1, $2, $3, $4::shift_type,
		        COALESCE((SELECT max(period_order) FROM class_periods
		                  WHERE day_of_week = $3 AND shift = $4::shift_type AND `+scope+`), 0) + 1,
		        $6::period_type, $7, $8, $9::time, $10::time, $11)
		RETURNING id`,
		p.CourseID, derefStr(p.WorkshopGroupID), p.DayOfWeek, p.Shift, scopeArg,
		p.PeriodType, derefStr(p.SubjectID), derefStr(p.TeacherID), p.StartTime, p.EndTime, p.IsFifthModule,
	).Scan(&id)
	if err != nil {
		return domain.ClassPeriod{}, mapDBError(err, "No se pudo crear el período.")
	}
	return scanClassPeriod(r.pool.QueryRow(ctx, classPeriodSelect+" WHERE cp.id = $1", id))
}

func (r *ClassPeriodRepo) Delete(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM class_periods WHERE id = $1`, id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}
