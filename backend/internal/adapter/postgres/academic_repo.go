package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

// ── subjects ─────────────────────────────────────────────────────────────────

type SubjectRepo struct{ pool *pgxpool.Pool }

func NewSubjectRepo(pool *pgxpool.Pool) *SubjectRepo { return &SubjectRepo{pool} }

func (r *SubjectRepo) GetAll(ctx context.Context, gradeYear *int, specialtyID *string) ([]domain.SubjectWithApplicability, error) {
	var q string
	var args []any
	if gradeYear != nil && specialtyID != nil {
		// Only the subjects enabled (via subject_applicability) for that
		// grade year + specialty — feeds the schedule-building dropdown.
		q = `SELECT DISTINCT s.id, s.name, s.subject_type::text, s.short_code, s.short_code_auto, s.is_active
		     FROM subjects s
		     JOIN subject_applicability sa ON sa.subject_id = s.id
		     WHERE sa.grade_year = $1 AND sa.specialty_id = $2
		     ORDER BY s.name`
		args = append(args, *gradeYear, *specialtyID)
	} else {
		q = `SELECT s.id, s.name, s.subject_type::text, s.short_code, s.short_code_auto, s.is_active FROM subjects s ORDER BY s.name`
	}
	rows, err := r.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	var subjects []domain.Subject
	for rows.Next() {
		var s domain.Subject
		if err := rows.Scan(&s.ID, &s.Name, &s.SubjectType, &s.ShortCode, &s.ShortCodeAuto, &s.IsActive); err != nil {
			rows.Close()
			return nil, err
		}
		subjects = append(subjects, s)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// One extra query for every subject_applicability row (catalogue-sized,
	// cheap), grouped in memory — avoids an N+1 request per subject for the
	// Materias screen's año/especialidad filters.
	appRows, err := r.pool.Query(ctx, applicabilitySelect+" ORDER BY sa.grade_year")
	if err != nil {
		return nil, err
	}
	defer appRows.Close()
	bySubject := make(map[string][]domain.SubjectApplicability)
	for appRows.Next() {
		a, err := scanApplicability(appRows)
		if err != nil {
			return nil, err
		}
		bySubject[a.SubjectID] = append(bySubject[a.SubjectID], a)
	}
	if err := appRows.Err(); err != nil {
		return nil, err
	}

	out := make([]domain.SubjectWithApplicability, 0, len(subjects))
	for _, s := range subjects {
		out = append(out, domain.SubjectWithApplicability{Subject: s, Applicability: bySubject[s.ID]})
	}
	return out, nil
}

func (r *SubjectRepo) GetByID(ctx context.Context, id string) (*domain.Subject, error) {
	var s domain.Subject
	err := r.pool.QueryRow(ctx,
		`SELECT id, name, subject_type::text, short_code, short_code_auto, is_active FROM subjects WHERE id = $1`, id).
		Scan(&s.ID, &s.Name, &s.SubjectType, &s.ShortCode, &s.ShortCodeAuto, &s.IsActive)
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *SubjectRepo) Create(ctx context.Context, name, subjectType, shortCode string) (domain.Subject, error) {
	var s domain.Subject
	err := r.pool.QueryRow(ctx,
		`INSERT INTO subjects (name, subject_type, short_code, short_code_auto)
		 VALUES ($1, $2::subject_type, $3, TRUE)
		 RETURNING id, name, subject_type::text, short_code, short_code_auto, is_active`,
		name, subjectType, shortCode).Scan(&s.ID, &s.Name, &s.SubjectType, &s.ShortCode, &s.ShortCodeAuto, &s.IsActive)
	if err != nil {
		if isUniqueViolation(err) {
			return domain.Subject{}, domain.NewDomainError(fmt.Sprintf("Ya existe una materia llamada '%s'.", name), 409)
		}
		return domain.Subject{}, mapDBError(err, "No se pudo crear la materia.")
	}
	return s, nil
}

func (r *SubjectRepo) UpdateShortCode(ctx context.Context, id, shortCode string, auto bool) (*domain.Subject, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE subjects SET short_code = $2, short_code_auto = $3 WHERE id = $1`,
		id, shortCode, auto)
	if err != nil {
		return nil, mapDBError(err, "No se pudo actualizar el identificador de la materia.")
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetByID(ctx, id)
}

func (r *SubjectRepo) UpdateDetails(ctx context.Context, id, name, subjectType string) (*domain.Subject, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE subjects SET name = $2, subject_type = $3::subject_type WHERE id = $1`,
		id, name, subjectType)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, domain.NewDomainError(fmt.Sprintf("Ya existe una materia llamada '%s'.", name), 409)
		}
		return nil, mapDBError(err, "No se pudo actualizar la materia.")
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetByID(ctx, id)
}

func (r *SubjectRepo) ToggleActive(ctx context.Context, id string) (*domain.Subject, error) {
	tag, err := r.pool.Exec(ctx, `UPDATE subjects SET is_active = NOT is_active WHERE id = $1`, id)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.GetByID(ctx, id)
}

// Delete hard-deletes a subject — only allowed once it's already been given
// de baja (is_active = false). Enforced here, not just in the panel, so the
// rule holds regardless of caller. Same pattern as StudentRepo.EliminarAlumno.
func (r *SubjectRepo) Delete(ctx context.Context, id string) (bool, error) {
	var isActive bool
	err := r.pool.QueryRow(ctx, `SELECT is_active FROM subjects WHERE id = $1`, id).Scan(&isActive)
	if noRows(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if isActive {
		return false, domain.NewDomainError("No se puede eliminar una materia activa: dala de baja primero.", 400)
	}

	tag, err := r.pool.Exec(ctx, `DELETE FROM subjects WHERE id = $1`, id)
	if err != nil {
		if isFKViolation(err) {
			return false, domain.NewDomainError(
				"No se puede eliminar: la materia tiene cursos o profesores asociados.", 409)
		}
		return false, mapDBError(err, "No se pudo eliminar la materia.")
	}
	return tag.RowsAffected() > 0, nil
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

func (r *SubjectApplicabilityRepo) SubjectIDFor(ctx context.Context, id string) (string, error) {
	var subjectID string
	err := r.pool.QueryRow(ctx, `SELECT subject_id FROM subject_applicability WHERE id = $1`, id).Scan(&subjectID)
	if noRows(err) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return subjectID, nil
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
	SELECT cst.course_id, cst.subject_id, sub.name, sub.subject_type::text, sub.short_code,
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
		&a.CourseID, &a.SubjectID, &a.SubjectName, &a.SubjectType, &a.SubjectShortCode,
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

func (r *CourseSubjectTeacherRepo) GetAll(ctx context.Context) ([]domain.SubjectTeacherAssignment, error) {
	return r.collect(ctx, "")
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
