package postgres

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type StudentRepo struct{ pool *pgxpool.Pool }

func NewStudentRepo(pool *pgxpool.Pool) *StudentRepo { return &StudentRepo{pool} }

const studentSelect = `
	SELECT s.id, s.first_name, s.last_name, COALESCE(s.document_number, ''),
	       s.course_id, s.is_repeating_student, s.is_active, s.workshop_group_id,
	       COALESCE(c.academic_year, 0), COALESCE(c.grade_year, 0), COALESCE(c.division, 0),
	       wg.group_label, COALESCE(sp.name, '')
	FROM students s
	LEFT JOIN courses c ON c.id = s.course_id
	LEFT JOIN workshop_groups wg ON wg.id = s.workshop_group_id
	LEFT JOIN specialties sp ON sp.id = c.specialty_id`

func scanAlumno(row pgx.Row) (domain.Alumno, error) {
	var a domain.Alumno
	var wgID, taller *string
	if err := row.Scan(
		&a.ID, &a.Nombre, &a.Apellido, &a.DNI, &a.CursoID, &a.Recursante, &a.IsActive, &wgID,
		&a.AcademicYear, &a.GradeYear, &a.Division, &taller, &a.Especialidad,
	); err != nil {
		return domain.Alumno{}, err
	}
	a.WorkshopGroupID = wgID
	a.Taller = taller
	if a.AcademicYear != 0 {
		a.Curso = domain.CourseLabel(a.AcademicYear, a.GradeYear, a.Division)
	}
	return a, nil
}

func (r *StudentRepo) list(ctx context.Context, where string, args ...any) ([]domain.Alumno, error) {
	rows, err := r.pool.Query(ctx, studentSelect+" "+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Alumno
	for rows.Next() {
		a, err := scanAlumno(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r *StudentRepo) GetAlumnos(ctx context.Context, includeInactive bool) ([]domain.Alumno, error) {
	if includeInactive {
		return r.list(ctx, "ORDER BY s.last_name, s.first_name")
	}
	return r.list(ctx, "WHERE s.is_active ORDER BY s.last_name, s.first_name")
}

func (r *StudentRepo) GetAlumnoPorID(ctx context.Context, id string) (*domain.Alumno, error) {
	a, err := scanAlumno(r.pool.QueryRow(ctx, studentSelect+" WHERE s.id = $1", id))
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (r *StudentRepo) GetAlumnosPorCurso(ctx context.Context, cursoID string) ([]domain.Alumno, error) {
	return r.list(ctx, "WHERE s.course_id = $1", cursoID)
}

func (r *StudentRepo) ExisteDNI(ctx context.Context, dni string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM students WHERE document_number = $1)`, dni).Scan(&exists)
	return exists, err
}

func (r *StudentRepo) CrearAlumnoManual(ctx context.Context, p domain.CrearAlumnoParams) (*domain.Alumno, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`INSERT INTO students (first_name, last_name, document_number, course_id, workshop_group_id)
		 VALUES ($1, $2, $3, $4, $5) RETURNING id`,
		p.FirstName, p.LastName, p.NationalID, p.CourseID, derefStr(p.WorkshopGroupID)).Scan(&id)
	if err != nil {
		return nil, mapDBError(err, "No se pudo crear el alumno.")
	}
	return r.GetAlumnoPorID(ctx, id)
}

func (r *StudentRepo) ToggleActive(ctx context.Context, id string) (*domain.Alumno, error) {
	tag, err := r.pool.Exec(ctx, `UPDATE students SET is_active = NOT is_active, updated_at = now() WHERE id = $1`, id)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetAlumnoPorID(ctx, id)
}

func (r *StudentRepo) ActualizarAlumno(ctx context.Context, id string, a domain.Alumno) (*domain.Alumno, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE students SET
		     first_name = $2,
		     last_name = $3,
		     document_number = $4,
		     course_id = $5,
		     workshop_group_id = $6,
		     updated_at = now()
		 WHERE id = $1`,
		id, a.Nombre, a.Apellido, a.DNI, a.CursoID, derefStr(a.WorkshopGroupID))
	if err != nil {
		return nil, mapDBError(err, "No se pudo actualizar el alumno.")
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetAlumnoPorID(ctx, id)
}
