package postgres

import (
	"context"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// ── shifts_config (editable label per shift_type) ──────────────────────────

type ShiftConfigRepo struct{ pool *pgxpool.Pool }

func NewShiftConfigRepo(pool *pgxpool.Pool) *ShiftConfigRepo { return &ShiftConfigRepo{pool} }

const shiftOrder = `CASE shift WHEN 'morning' THEN 1 WHEN 'afternoon' THEN 2 ELSE 3 END`

func (r *ShiftConfigRepo) GetAll(ctx context.Context) ([]domain.ShiftConfig, error) {
	rows, err := r.pool.Query(ctx, `SELECT shift::text, label FROM shifts_config ORDER BY `+shiftOrder)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.ShiftConfig
	for rows.Next() {
		var s domain.ShiftConfig
		if err := rows.Scan(&s.Shift, &s.Label); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

func (r *ShiftConfigRepo) UpdateLabel(ctx context.Context, shift, label string) (*domain.ShiftConfig, error) {
	tag, err := r.pool.Exec(ctx, `UPDATE shifts_config SET label = $2 WHERE shift = $1::shift_type`, shift, label)
	if err != nil {
		return nil, mapDBError(err, "No se pudo actualizar el turno.")
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	var s domain.ShiftConfig
	if err := r.pool.QueryRow(ctx, `SELECT shift::text, label FROM shifts_config WHERE shift = $1::shift_type`, shift).
		Scan(&s.Shift, &s.Label); err != nil {
		return nil, err
	}
	return &s, nil
}

// ── shift_breaks ──────────────────────────────────────────────────────────

type ShiftBreakRepo struct{ pool *pgxpool.Pool }

func NewShiftBreakRepo(pool *pgxpool.Pool) *ShiftBreakRepo { return &ShiftBreakRepo{pool} }

const shiftBreakCols = `id, shift::text, label, to_char(start_time, 'HH24:MI'), to_char(end_time, 'HH24:MI')`

func scanShiftBreak(row pgx.Row) (domain.ShiftBreak, error) {
	var b domain.ShiftBreak
	err := row.Scan(&b.ID, &b.Shift, &b.Label, &b.StartTime, &b.EndTime)
	return b, err
}

func (r *ShiftBreakRepo) GetByShift(ctx context.Context, shift string) ([]domain.ShiftBreak, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+shiftBreakCols+` FROM shift_breaks WHERE shift = $1::shift_type ORDER BY start_time`, shift)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.ShiftBreak
	for rows.Next() {
		b, err := scanShiftBreak(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (r *ShiftBreakRepo) Create(ctx context.Context, shift, label, startTime, endTime string) (domain.ShiftBreak, error) {
	b, err := scanShiftBreak(r.pool.QueryRow(ctx,
		`INSERT INTO shift_breaks (shift, label, start_time, end_time)
		 VALUES ($1::shift_type, $2, $3::time, $4::time)
		 RETURNING `+shiftBreakCols,
		shift, label, startTime, endTime))
	if err != nil {
		return domain.ShiftBreak{}, mapDBError(err, "No se pudo crear el recreo.")
	}
	return b, nil
}

func (r *ShiftBreakRepo) Delete(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM shift_breaks WHERE id = $1`, id)
	if err != nil {
		return false, mapDBError(err, "No se pudo eliminar el recreo.")
	}
	return tag.RowsAffected() > 0, nil
}

// ── academic structure (year_structure + division_workshop_structure) ──────

type CourseStructureRepo struct{ pool *pgxpool.Pool }

func NewCourseStructureRepo(pool *pgxpool.Pool) *CourseStructureRepo { return &CourseStructureRepo{pool} }

func (r *CourseStructureRepo) Get(ctx context.Context) (domain.CoursesStructure, error) {
	var out domain.CoursesStructure
	if err := r.pool.QueryRow(ctx,
		`SELECT max_grade_year, current_academic_year FROM school_settings LIMIT 1`).
		Scan(&out.MaxGradeYear, &out.CurrentAcademicYear); err != nil {
		if noRows(err) {
			d := domain.DefaultSchoolSettings()
			out.MaxGradeYear, out.CurrentAcademicYear = d.MaxGradeYear, d.CurrentAcademicYear
		} else {
			return domain.CoursesStructure{}, err
		}
	}

	divCount := map[int]int{}
	rows, err := r.pool.Query(ctx, `SELECT grade_year, division_count FROM year_structure`)
	if err != nil {
		return domain.CoursesStructure{}, err
	}
	for rows.Next() {
		var gy, dc int
		if err := rows.Scan(&gy, &dc); err != nil {
			rows.Close()
			return domain.CoursesStructure{}, err
		}
		divCount[gy] = dc
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return domain.CoursesStructure{}, err
	}

	wsCount := map[[2]int]int{}
	rows, err = r.pool.Query(ctx, `SELECT grade_year, division, workshop_group_count FROM division_workshop_structure`)
	if err != nil {
		return domain.CoursesStructure{}, err
	}
	for rows.Next() {
		var gy, dv, wc int
		if err := rows.Scan(&gy, &dv, &wc); err != nil {
			rows.Close()
			return domain.CoursesStructure{}, err
		}
		wsCount[[2]int{gy, dv}] = wc
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return domain.CoursesStructure{}, err
	}

	for gy := 1; gy <= out.MaxGradeYear; gy++ {
		dc := divCount[gy]
		if dc < 1 {
			dc = 1
		}
		y := domain.YearDivisionStructure{GradeYear: gy, DivisionCount: dc}
		for dv := 1; dv <= dc; dv++ {
			y.Divisions = append(y.Divisions, domain.DivisionStructure{
				Division:           dv,
				WorkshopGroupCount: wsCount[[2]int{gy, dv}],
			})
		}
		out.Years = append(out.Years, y)
	}
	return out, nil
}

func (r *CourseStructureRepo) MaxDivision(ctx context.Context) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COALESCE(MAX(division_count), 1) FROM year_structure`).Scan(&n)
	return n, err
}

// Replace reconciles the whole structure. Any reduction that would strand an
// existing courses / workshop_groups row is refused with a *DomainError (400).
func (r *CourseStructureRepo) Replace(ctx context.Context, in domain.CoursesStructure) (domain.CoursesStructure, error) {
	if in.MaxGradeYear < 1 || in.MaxGradeYear > 7 {
		return domain.CoursesStructure{}, domain.NewDomainError("La cantidad de años debe estar entre 1 y 7.", 400)
	}
	if in.CurrentAcademicYear < 2000 || in.CurrentAcademicYear > 2100 {
		return domain.CoursesStructure{}, domain.NewDomainError("El año lectivo actual no es válido.", 400)
	}

	// Guard: courses beyond the requested number of years.
	var n int
	if err := r.pool.QueryRow(ctx,
		`SELECT count(*) FROM courses WHERE grade_year > $1`, in.MaxGradeYear).Scan(&n); err != nil {
		return domain.CoursesStructure{}, err
	}
	if n > 0 {
		return domain.CoursesStructure{}, domain.NewDomainError(fmt.Sprintf(
			"Hay %d curso(s) de un año mayor a %d°. Eliminá esos cursos antes de bajar la cantidad de años.", n, in.MaxGradeYear), 400)
	}

	years := append([]domain.YearDivisionStructure(nil), in.Years...)
	sort.Slice(years, func(i, j int) bool { return years[i].GradeYear < years[j].GradeYear })

	for _, y := range years {
		if y.GradeYear < 1 || y.GradeYear > in.MaxGradeYear {
			continue
		}
		if y.DivisionCount < 1 {
			return domain.CoursesStructure{}, domain.NewDomainError(
				fmt.Sprintf("%d° debe tener al menos 1 división.", y.GradeYear), 400)
		}
		var maxDiv int
		if err := r.pool.QueryRow(ctx,
			`SELECT COALESCE(MAX(division), 0) FROM courses WHERE grade_year = $1`, y.GradeYear).Scan(&maxDiv); err != nil {
			return domain.CoursesStructure{}, err
		}
		if maxDiv > y.DivisionCount {
			return domain.CoursesStructure{}, domain.NewDomainError(fmt.Sprintf(
				"%d° ya tiene la división %d cargada. No podés bajar a %d divisiones sin eliminar ese curso primero.",
				y.GradeYear, maxDiv, y.DivisionCount), 400)
		}
		for _, d := range y.Divisions {
			if d.Division < 1 || d.Division > y.DivisionCount {
				continue
			}
			if d.WorkshopGroupCount < 0 {
				return domain.CoursesStructure{}, domain.NewDomainError("La cantidad de grupos de taller no puede ser negativa.", 400)
			}
			var maxGroups int
			if err := r.pool.QueryRow(ctx, `
				SELECT COALESCE(MAX(cnt), 0) FROM (
					SELECT count(*) AS cnt
					FROM workshop_groups wg
					JOIN courses c ON c.id = wg.course_id
					WHERE c.grade_year = $1 AND c.division = $2
					GROUP BY wg.course_id
				) t`, y.GradeYear, d.Division).Scan(&maxGroups); err != nil {
				return domain.CoursesStructure{}, err
			}
			if maxGroups > d.WorkshopGroupCount {
				return domain.CoursesStructure{}, domain.NewDomainError(fmt.Sprintf(
					"%d° %d° ya tiene un curso con %d grupos de taller. No podés bajar a %d sin eliminar grupos primero.",
					y.GradeYear, d.Division, maxGroups, d.WorkshopGroupCount), 400)
			}
		}
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return domain.CoursesStructure{}, err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx,
		`UPDATE school_settings SET max_grade_year = $1, current_academic_year = $2 WHERE id = TRUE`,
		in.MaxGradeYear, in.CurrentAcademicYear); err != nil {
		return domain.CoursesStructure{}, mapDBError(err, "No se pudo guardar la estructura.")
	}
	for _, y := range years {
		if y.GradeYear < 1 || y.GradeYear > in.MaxGradeYear {
			continue
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO year_structure (grade_year, division_count) VALUES ($1, $2)
			ON CONFLICT (grade_year) DO UPDATE SET division_count = EXCLUDED.division_count`,
			y.GradeYear, y.DivisionCount); err != nil {
			return domain.CoursesStructure{}, mapDBError(err, "No se pudo guardar las divisiones.")
		}
		for _, d := range y.Divisions {
			if d.Division < 1 || d.Division > y.DivisionCount {
				continue
			}
			if _, err := tx.Exec(ctx, `
				INSERT INTO division_workshop_structure (grade_year, division, workshop_group_count)
				VALUES ($1, $2, $3)
				ON CONFLICT (grade_year, division) DO UPDATE SET workshop_group_count = EXCLUDED.workshop_group_count`,
				y.GradeYear, d.Division, d.WorkshopGroupCount); err != nil {
				return domain.CoursesStructure{}, mapDBError(err, "No se pudo guardar los grupos de taller.")
			}
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.CoursesStructure{}, err
	}
	return r.Get(ctx)
}
