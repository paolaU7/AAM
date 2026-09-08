package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type SpecialtyRepo struct{ pool *pgxpool.Pool }

func NewSpecialtyRepo(pool *pgxpool.Pool) *SpecialtyRepo { return &SpecialtyRepo{pool} }

func (r *SpecialtyRepo) GetAll(ctx context.Context) ([]domain.Specialty, error) {
	rows, err := r.pool.Query(ctx, `SELECT id, name, is_basic_cycle FROM specialties ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Specialty
	for rows.Next() {
		var s domain.Specialty
		if err := rows.Scan(&s.ID, &s.Name, &s.IsBasicCycle); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

func (r *SpecialtyRepo) GetByID(ctx context.Context, id string) (*domain.Specialty, error) {
	var s domain.Specialty
	err := r.pool.QueryRow(ctx, `SELECT id, name, is_basic_cycle FROM specialties WHERE id = $1`, id).
		Scan(&s.ID, &s.Name, &s.IsBasicCycle)
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

type SchoolSettingsRepo struct{ pool *pgxpool.Pool }

func NewSchoolSettingsRepo(pool *pgxpool.Pool) *SchoolSettingsRepo { return &SchoolSettingsRepo{pool} }

// Get returns the single settings row, or safe defaults when the seeded row is
// missing (mirrors SchoolSettingsRepositoryImpl.get()).
func (r *SchoolSettingsRepo) Get(ctx context.Context) (domain.SchoolSettings, error) {
	var s domain.SchoolSettings
	err := r.pool.QueryRow(ctx, `
		SELECT max_grade_year, max_division,
		       consecutive_absences_alert_threshold,
		       preceptor_temp_assignment_alert_days,
		       schedule_exception_alert_days
		FROM school_settings LIMIT 1`).
		Scan(&s.MaxGradeYear, &s.MaxDivision,
			&s.ConsecutiveAbsencesAlertThreshold,
			&s.PreceptorTempAssignmentAlertDays,
			&s.ScheduleExceptionAlertDays)
	if noRows(err) {
		return domain.DefaultSchoolSettings(), nil
	}
	if err != nil {
		return domain.SchoolSettings{}, err
	}
	return s, nil
}
