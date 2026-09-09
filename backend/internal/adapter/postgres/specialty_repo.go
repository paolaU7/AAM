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

const schoolSettingsCols = `
	max_grade_year, current_academic_year,
	to_char(lunch_start, 'HH24:MI'),
	to_char(lunch_start_fifth_module, 'HH24:MI'),
	to_char(lunch_end, 'HH24:MI'),
	consecutive_absences_alert_threshold,
	preceptor_temp_assignment_alert_days,
	schedule_exception_alert_days`

func scanSchoolSettings(row interface{ Scan(...any) error }) (domain.SchoolSettings, error) {
	var s domain.SchoolSettings
	err := row.Scan(&s.MaxGradeYear, &s.CurrentAcademicYear,
		&s.LunchStart, &s.LunchStartFifthModule, &s.LunchEnd,
		&s.ConsecutiveAbsencesAlertThreshold,
		&s.PreceptorTempAssignmentAlertDays,
		&s.ScheduleExceptionAlertDays)
	return s, err
}

// Get returns the single settings row, or safe defaults when it is missing.
func (r *SchoolSettingsRepo) Get(ctx context.Context) (domain.SchoolSettings, error) {
	s, err := scanSchoolSettings(r.pool.QueryRow(ctx, `SELECT `+schoolSettingsCols+` FROM school_settings LIMIT 1`))
	if noRows(err) {
		return domain.DefaultSchoolSettings(), nil
	}
	if err != nil {
		return domain.SchoolSettings{}, err
	}
	return s, nil
}

// Update writes the singleton row (id = TRUE). Range checks happen in the app
// layer; the schema CHECKs are the backstop (surface as 400 via mapDBError).
func (r *SchoolSettingsRepo) Update(ctx context.Context, s domain.SchoolSettings) (domain.SchoolSettings, error) {
	out, err := scanSchoolSettings(r.pool.QueryRow(ctx, `
		INSERT INTO school_settings (
			id, max_grade_year, current_academic_year,
			lunch_start, lunch_start_fifth_module, lunch_end,
			consecutive_absences_alert_threshold,
			preceptor_temp_assignment_alert_days,
			schedule_exception_alert_days
		) VALUES (TRUE, $1, $2, $3::time, $4::time, $5::time, $6, $7, $8)
		ON CONFLICT (id) DO UPDATE SET
			max_grade_year = EXCLUDED.max_grade_year,
			current_academic_year = EXCLUDED.current_academic_year,
			lunch_start = EXCLUDED.lunch_start,
			lunch_start_fifth_module = EXCLUDED.lunch_start_fifth_module,
			lunch_end = EXCLUDED.lunch_end,
			consecutive_absences_alert_threshold = EXCLUDED.consecutive_absences_alert_threshold,
			preceptor_temp_assignment_alert_days = EXCLUDED.preceptor_temp_assignment_alert_days,
			schedule_exception_alert_days = EXCLUDED.schedule_exception_alert_days
		RETURNING `+schoolSettingsCols,
		s.MaxGradeYear, s.CurrentAcademicYear,
		s.LunchStart, s.LunchStartFifthModule, s.LunchEnd,
		s.ConsecutiveAbsencesAlertThreshold,
		s.PreceptorTempAssignmentAlertDays,
		s.ScheduleExceptionAlertDays))
	if err != nil {
		return domain.SchoolSettings{}, mapDBError(err, "No se pudo actualizar la configuración.")
	}
	return out, nil
}
