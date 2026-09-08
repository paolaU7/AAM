package postgres

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// ── subjects ─────────────────────────────────────────────────────────────────

type SubjectRepo struct{ pool *pgxpool.Pool }

func NewSubjectRepo(pool *pgxpool.Pool) *SubjectRepo { return &SubjectRepo{pool} }

func (r *SubjectRepo) GetAll(ctx context.Context, gradeYear *int, specialtyID *string) ([]domain.Subject, error) {
	var q string
	var args []any
	if gradeYear != nil && specialtyID != nil {
		// Only the subjects enabled (via subject_applicability) for that
		// grade year + specialty — feeds the schedule-building dropdown.
		q = `SELECT DISTINCT s.id, s.name, s.subject_type::text
		     FROM subjects s
		     JOIN subject_applicability sa ON sa.subject_id = s.id
		     WHERE sa.grade_year = $1 AND sa.specialty_id = $2
		     ORDER BY s.name`
		args = append(args, *gradeYear, *specialtyID)
	} else {
		q = `SELECT s.id, s.name, s.subject_type::text FROM subjects s ORDER BY s.name`
	}
	rows, err := r.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Subject
	for rows.Next() {
		var s domain.Subject
		if err := rows.Scan(&s.ID, &s.Name, &s.SubjectType); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

func (r *SubjectRepo) GetByID(ctx context.Context, id string) (*domain.Subject, error) {
	var s domain.Subject
	err := r.pool.QueryRow(ctx, `SELECT id, name, subject_type::text FROM subjects WHERE id = $1`, id).
		Scan(&s.ID, &s.Name, &s.SubjectType)
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SubjectRepo) Create(ctx context.Context, name, subjectType string) (domain.Subject, error) {
	var s domain.Subject
	err := r.pool.QueryRow(ctx,
		`INSERT INTO subjects (name, subject_type) VALUES ($1, $2::subject_type)
		 RETURNING id, name, subject_type::text`,
		name, subjectType).Scan(&s.ID, &s.Name, &s.SubjectType)
	if err != nil {
		return domain.Subject{}, mapDBError(err, "No se pudo crear la materia.")
	}
	return s, nil
}

// ── subject_applicability ────────────────────────────────────────────────────

type SubjectApplicabilityRepo struct{ pool *pgxpool.Pool }

func NewSubjectApplicabilityRepo(pool *pgxpool.Pool) *SubjectApplicabilityRepo {
	return &SubjectApplicabilityRepo{pool}
}

const applicabilitySelect = `
	SELECT sa.id, sa.subject_id, sa.grade_year, sa.specialty_id, sp.name
	FROM subject_applicability sa
	JOIN specialties sp ON sp.id = sa.specialty_id`

func scanApplicability(row pgx.Row) (domain.SubjectApplicability, error) {
	var a domain.SubjectApplicability
	err := row.Scan(&a.ID, &a.SubjectID, &a.GradeYear, &a.SpecialtyID, &a.SpecialtyName)
	return a, err
}

func (r *SubjectApplicabilityRepo) GetBySubject(ctx context.Context, subjectID string) ([]domain.SubjectApplicability, error) {
	rows, err := r.pool.Query(ctx, applicabilitySelect+" WHERE sa.subject_id = $1 ORDER BY sa.grade_year", subjectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.SubjectApplicability
	for rows.Next() {
		a, err := scanApplicability(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r *SubjectApplicabilityRepo) Add(ctx context.Context, subjectID string, gradeYear int, specialtyID string) (domain.SubjectApplicability, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`INSERT INTO subject_applicability (subject_id, grade_year, specialty_id) VALUES ($1, $2, $3) RETURNING id`,
		subjectID, gradeYear, specialtyID).Scan(&id)
	if err != nil {
		return domain.SubjectApplicability{}, mapDBError(err, "No se pudo agregar la aplicabilidad.")
	}
	a, err := scanApplicability(r.pool.QueryRow(ctx, applicabilitySelect+" WHERE sa.id = $1", id))
	return a, err
}

func (r *SubjectApplicabilityRepo) Remove(ctx context.Context, id string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM subject_applicability WHERE id = $1`, id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// ── teachers ─────────────────────────────────────────────────────────────────

type TeacherRepo struct{ pool *pgxpool.Pool }

func NewTeacherRepo(pool *pgxpool.Pool) *TeacherRepo { return &TeacherRepo{pool} }

func scanTeacher(row pgx.Row) (domain.Teacher, error) {
	var t domain.Teacher
	err := row.Scan(&t.ID, &t.FullName, &t.Email, &t.Phone)
	return t, err
}

func (r *TeacherRepo) GetAll(ctx context.Context) ([]domain.Teacher, error) {
	rows, err := r.pool.Query(ctx, `SELECT id, full_name, email, phone FROM teachers ORDER BY full_name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.Teacher
	for rows.Next() {
		t, err := scanTeacher(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (r *TeacherRepo) Create(ctx context.Context, fullName string, email, phone *string) (domain.Teacher, error) {
	t, err := scanTeacher(r.pool.QueryRow(ctx,
		`INSERT INTO teachers (full_name, email, phone) VALUES ($1, $2, $3)
		 RETURNING id, full_name, email, phone`,
		fullName, derefStr(email), derefStr(phone)))
	if err != nil {
		return domain.Teacher{}, mapDBError(err, "No se pudo crear el profesor.")
	}
	return t, nil
}

// ── course_subject_teachers ──────────────────────────────────────────────────

type CourseSubjectTeacherRepo struct{ pool *pgxpool.Pool }

func NewCourseSubjectTeacherRepo(pool *pgxpool.Pool) *CourseSubjectTeacherRepo {
	return &CourseSubjectTeacherRepo{pool}
}

const cstSelect = `
	SELECT cst.course_id, cst.subject_id, sub.name, sub.subject_type::text,
	       cst.teacher_id, t.full_name, t.email, t.phone,
	       (c.id IS NOT NULL) AS has_course,
	       COALESCE(c.academic_year, 0), COALESCE(c.grade_year, 0), COALESCE(c.division, 0)
	FROM course_subject_teachers cst
	JOIN subjects sub ON sub.id = cst.subject_id
	JOIN teachers t ON t.id = cst.teacher_id
	LEFT JOIN courses c ON c.id = cst.course_id`

func scanCST(row pgx.Row) (domain.SubjectTeacherAssignment, error) {
	var a domain.SubjectTeacherAssignment
	var hasCourse bool
	var ay, gy, dv int
	if err := row.Scan(
		&a.CourseID, &a.SubjectID, &a.SubjectName, &a.SubjectType,
		&a.TeacherID, &a.TeacherName, &a.TeacherEmail, &a.TeacherPhone,
		&hasCourse, &ay, &gy, &dv,
	); err != nil {
		return domain.SubjectTeacherAssignment{}, err
	}
	if hasCourse {
		label := domain.CourseLabel(ay, gy, dv)
		a.CourseName = &label
	}
	return a, nil
}

func (r *CourseSubjectTeacherRepo) collect(ctx context.Context, where string, args ...any) ([]domain.SubjectTeacherAssignment, error) {
	rows, err := r.pool.Query(ctx, cstSelect+" "+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.SubjectTeacherAssignment
	for rows.Next() {
		a, err := scanCST(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r *CourseSubjectTeacherRepo) GetByCourse(ctx context.Context, courseID string) ([]domain.SubjectTeacherAssignment, error) {
	return r.collect(ctx, "WHERE cst.course_id = $1", courseID)
}

func (r *CourseSubjectTeacherRepo) GetByTeacher(ctx context.Context, teacherID string) ([]domain.SubjectTeacherAssignment, error) {
	return r.collect(ctx, "WHERE cst.teacher_id = $1", teacherID)
}

func (r *CourseSubjectTeacherRepo) Assign(ctx context.Context, courseID, subjectID, teacherID string) (domain.SubjectTeacherAssignment, error) {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO course_subject_teachers (course_id, subject_id, teacher_id)
		VALUES ($1, $2, $3)
		ON CONFLICT (course_id, subject_id) DO UPDATE SET teacher_id = EXCLUDED.teacher_id`,
		courseID, subjectID, teacherID)
	if err != nil {
		return domain.SubjectTeacherAssignment{}, mapDBError(err, "No se pudo asignar la materia.")
	}
	list, err := r.collect(ctx, "WHERE cst.course_id = $1 AND cst.subject_id = $2", courseID, subjectID)
	if err != nil {
		return domain.SubjectTeacherAssignment{}, err
	}
	if len(list) == 0 {
		return domain.SubjectTeacherAssignment{}, domain.NewDomainError("No se pudo asignar la materia.", 400)
	}
	return list[0], nil
}

func (r *CourseSubjectTeacherRepo) Remove(ctx context.Context, courseID, subjectID string) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM course_subject_teachers WHERE course_id = $1 AND subject_id = $2`, courseID, subjectID)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}
