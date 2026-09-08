package postgres

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type CourseRepo struct{ pool *pgxpool.Pool }

func NewCourseRepo(pool *pgxpool.Pool) *CourseRepo { return &CourseRepo{pool} }

const courseSelect = `
	SELECT c.id, c.academic_year, c.grade_year, c.division, c.specialty_id,
	       COALESCE(sp.name, '') AS specialty_name,
	       (SELECT count(*) FROM students s WHERE s.course_id = c.id) AS total_students
	FROM courses c
	LEFT JOIN specialties sp ON sp.id = c.specialty_id`

func scanCourse(row pgx.Row) (domain.Course, error) {
	var c domain.Course
	err := row.Scan(&c.ID, &c.AcademicYear, &c.GradeYear, &c.Division, &c.SpecialtyID, &c.SpecialtyName, &c.TotalStudents)
	if err != nil {
		return domain.Course{}, err
	}
	c.Name = domain.CourseLabel(c.AcademicYear, c.GradeYear, c.Division)
	return c, nil
}

func (r *CourseRepo) GetCourses(ctx context.Context) ([]domain.Course, error) {
	rows, err := r.pool.Query(ctx, courseSelect+" ORDER BY c.academic_year, c.grade_year, c.division")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Course
	for rows.Next() {
		c, err := scanCourse(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *CourseRepo) GetCourseByID(ctx context.Context, id string) (*domain.Course, error) {
	c, err := scanCourse(r.pool.QueryRow(ctx, courseSelect+" WHERE c.id = $1", id))
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *CourseRepo) ResolveCourse(ctx context.Context, academicYear, gradeYear, division int) (*domain.Course, error) {
	c, err := scanCourse(r.pool.QueryRow(ctx,
		courseSelect+" WHERE c.academic_year = $1 AND c.grade_year = $2 AND c.division = $3",
		academicYear, gradeYear, division))
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *CourseRepo) CreateCourse(ctx context.Context, academicYear, gradeYear, division int, specialtyID string) (*domain.Course, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`INSERT INTO courses (academic_year, grade_year, division, specialty_id)
		 VALUES ($1, $2, $3, $4) RETURNING id`,
		academicYear, gradeYear, division, specialtyID).Scan(&id)
	if err != nil {
		return nil, mapDBError(err, "No se pudo guardar el curso.")
	}
	return r.GetCourseByID(ctx, id)
}

func (r *CourseRepo) UpdateCourse(ctx context.Context, id string, academicYear, gradeYear, division int, specialtyID string) (*domain.Course, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE courses SET academic_year = $2, grade_year = $3, division = $4, specialty_id = $5
		 WHERE id = $1`,
		id, academicYear, gradeYear, division, specialtyID)
	if err != nil {
		return nil, mapDBError(err, "No se pudo guardar el curso.")
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetCourseByID(ctx, id)
}
