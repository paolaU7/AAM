package app

import (
	"context"
	"strings"

	"github.com/paolaU7/AAM/backend/internal/domain"
)

// AcademicService covers academic_usecases.py (subjects, applicability,
// teachers, course-subject-teacher assignments).
type AcademicService struct {
	Subjects      domain.SubjectRepo
	Applicability domain.SubjectApplicabilityRepo
	Teachers      domain.TeacherRepo
	CourseSubject domain.CourseSubjectTeacherRepo
	Specialty     domain.SpecialtyRepo
	Courses       domain.CourseRepo
}

func (s AcademicService) ListSubjects(ctx context.Context, gradeYear *int, specialtyID *string) ([]domain.SubjectWithApplicability, error) {
	return s.Subjects.GetAll(ctx, gradeYear, specialtyID)
}

func (s AcademicService) CreateSubject(ctx context.Context, name, subjectType string) (domain.Subject, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return domain.Subject{}, domain.NewDomainError("El nombre de la materia es obligatorio.", 400)
	}
	if subjectType != domain.SubjectCurricular && subjectType != domain.SubjectWorkshop {
		return domain.Subject{}, domain.NewDomainError("El tipo de materia debe ser 'curricular' o 'workshop'.", 400)
	}
	// Recién creada no tiene aplicabilidad todavía — el código sale solo de
	// las iniciales del nombre (ej. "Matemática" -> "M").
	shortCode := domain.ComputeSubjectShortCode(name, nil)
	return s.Subjects.Create(ctx, name, subjectType, shortCode)
}

// computeAutoShortCode derives what subj's short_code *would* be right now,
// from its name and its current subject_applicability grade years.
func (s AcademicService) computeAutoShortCode(ctx context.Context, subj domain.Subject) (string, error) {
	rows, err := s.Applicability.GetBySubject(ctx, subj.ID)
	if err != nil {
		return "", err
	}
	years := make([]int, len(rows))
	for i, a := range rows {
		years[i] = a.GradeYear
	}
	return domain.ComputeSubjectShortCode(subj.Name, years), nil
}

// recomputeShortCode regenerates and persists subjectID's short_code from its
// current name + applicability — but only while it's still auto-generated
// (ShortCodeAuto). A subject whose code was edited by hand is left alone.
// Called after every subject_applicability change.
func (s AcademicService) recomputeShortCode(ctx context.Context, subjectID string) error {
	subj, err := s.Subjects.GetByID(ctx, subjectID)
	if err != nil || subj == nil || !subj.ShortCodeAuto {
		return err
	}
	code, err := s.computeAutoShortCode(ctx, *subj)
	if err != nil {
		return err
	}
	_, err = s.Subjects.UpdateShortCode(ctx, subjectID, code, true)
	return err
}

// UpdateSubjectShortCode is the manual-edit entry point. A blank shortCode
// means "volver a automático": recompute from the current name/applicability
// and mark it auto again. A non-blank one is stored verbatim as a manual
// override (ShortCodeAuto = false), so it stops being touched by
// recomputeShortCode from then on — the escape hatch for two subjects whose
// generated codes collide.
func (s AcademicService) UpdateSubjectShortCode(ctx context.Context, id, shortCode string) (*domain.Subject, error) {
	shortCode = strings.TrimSpace(shortCode)
	if shortCode != "" {
		return s.Subjects.UpdateShortCode(ctx, id, shortCode, false)
	}
	subj, err := s.Subjects.GetByID(ctx, id)
	if err != nil || subj == nil {
		return subj, err
	}
	code, err := s.computeAutoShortCode(ctx, *subj)
	if err != nil {
		return nil, err
	}
	return s.Subjects.UpdateShortCode(ctx, id, code, true)
}

// UpdateSubjectDetails lets name + type be edited after creation (the pencil
// in the Materias screen). If the short_code is still automatic, it's
// recomputed from the new name (the years/especialidades don't change here).
func (s AcademicService) UpdateSubjectDetails(ctx context.Context, id, name, subjectType string) (*domain.Subject, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, domain.NewDomainError("El nombre de la materia es obligatorio.", 400)
	}
	if subjectType != domain.SubjectCurricular && subjectType != domain.SubjectWorkshop {
		return nil, domain.NewDomainError("El tipo de materia debe ser 'curricular' o 'workshop'.", 400)
	}
	subj, err := s.Subjects.UpdateDetails(ctx, id, name, subjectType)
	if err != nil || subj == nil {
		return subj, err
	}
	if subj.ShortCodeAuto {
		code, err := s.computeAutoShortCode(ctx, *subj)
		if err != nil {
			return subj, err
		}
		updated, err := s.Subjects.UpdateShortCode(ctx, id, code, true)
		if err != nil {
			return subj, err
		}
		if updated != nil {
			subj = updated
		}
	}
	return subj, nil
}

func (s AcademicService) ToggleSubjectActive(ctx context.Context, id string) (*domain.Subject, error) {
	return s.Subjects.ToggleActive(ctx, id)
}

// DeleteSubject is the hard delete. The repo rejects it (400) unless the
// subject is already dada de baja, and (409) if it has associated courses,
// teachers or schedule rows.
func (s AcademicService) DeleteSubject(ctx context.Context, id string) (bool, error) {
	return s.Subjects.Delete(ctx, id)
}

func (s AcademicService) SubjectApplicability(ctx context.Context, subjectID string) ([]domain.SubjectApplicability, error) {
	return s.Applicability.GetBySubject(ctx, subjectID)
}

// AddApplicability mirrors AddSubjectApplicability, including the Ciclo Básico rule.
func (s AcademicService) AddApplicability(ctx context.Context, subjectID string, gradeYear int, specialtyID string) (domain.SubjectApplicability, error) {
	subj, err := s.Subjects.GetByID(ctx, subjectID)
	if err != nil {
		return domain.SubjectApplicability{}, err
	}
	if subj == nil {
		return domain.SubjectApplicability{}, domain.NewDomainError("La materia no existe.", 404)
	}
	if gradeYear < 1 || gradeYear > 7 {
		return domain.SubjectApplicability{}, domain.NewDomainError("El año de cursada debe estar entre 1 y 7.", 400)
	}
	if specialtyID == "" {
		return domain.SubjectApplicability{}, domain.NewDomainError("Seleccioná la especialidad.", 400)
	}
	sp, err := s.Specialty.GetByID(ctx, specialtyID)
	if err != nil {
		return domain.SubjectApplicability{}, err
	}
	if err := domain.ValidateBasicCycleSpecialty(sp, gradeYear, true); err != nil {
		return domain.SubjectApplicability{}, err
	}
	added, err := s.Applicability.Add(ctx, subjectID, gradeYear, specialtyID)
	if err != nil {
		return domain.SubjectApplicability{}, err
	}
	if err := s.recomputeShortCode(ctx, subjectID); err != nil {
		return domain.SubjectApplicability{}, err
	}
	return added, nil
}

// RemoveApplicability needs the owning subject's id to recompute its
// short_code afterwards, so it looks the row up first instead of deleting
// blind by id.
func (s AcademicService) RemoveApplicability(ctx context.Context, id string) (bool, error) {
	// Ask the repo which subject this applicability row belongs to before
	// removing it — Remove only takes the row id, not the subject id, but we
	// need the subject id afterwards to recompute its short_code.
	subjectID, err := s.Applicability.SubjectIDFor(ctx, id)
	if err != nil {
		return false, err
	}
	ok, err := s.Applicability.Remove(ctx, id)
	if err != nil || !ok {
		return ok, err
	}
	if subjectID != "" {
		if err := s.recomputeShortCode(ctx, subjectID); err != nil {
			return ok, err
		}
	}
	return ok, nil
}

// ListTeachers embeds each teacher's course_subject_teachers rows (one extra,
// catalogue-sized query, grouped in memory) so the Profesores screen can show
// a "materias asignadas" column without a request per row — same approach as
// ListSubjects embedding subject_applicability.
func (s AcademicService) ListTeachers(ctx context.Context, subjectID *string) ([]domain.TeacherWithAssignments, error) {
	teachers, err := s.Teachers.GetAll(ctx, subjectID)
	if err != nil {
		return nil, err
	}
	assignments, err := s.CourseSubject.GetAll(ctx)
	if err != nil {
		return nil, err
	}
	byTeacher := make(map[string][]domain.SubjectTeacherAssignment)
	for _, a := range assignments {
		byTeacher[a.TeacherID] = append(byTeacher[a.TeacherID], a)
	}
	out := make([]domain.TeacherWithAssignments, 0, len(teachers))
	for _, t := range teachers {
		out = append(out, domain.TeacherWithAssignments{Teacher: t, Assignments: byTeacher[t.ID]})
	}
	return out, nil
}

func (s AcademicService) CreateTeacher(ctx context.Context, fullName string, email, phone *string) (domain.Teacher, error) {
	fullName = strings.TrimSpace(fullName)
	if fullName == "" {
		return domain.Teacher{}, domain.NewDomainError("El nombre del profesor es obligatorio.", 400)
	}
	return s.Teachers.Create(ctx, fullName, nilIfEmpty(email), nilIfEmpty(phone))
}

func (s AcademicService) UpdateTeacher(ctx context.Context, id, fullName string, email, phone *string) (*domain.Teacher, error) {
	fullName = strings.TrimSpace(fullName)
	if fullName == "" {
		return nil, domain.NewDomainError("El nombre del profesor es obligatorio.", 400)
	}
	return s.Teachers.Update(ctx, id, fullName, nilIfEmpty(email), nilIfEmpty(phone))
}

func (s AcademicService) UpdateTeacherStatus(ctx context.Context, id, status string, reason, returnDate *string) (*domain.Teacher, error) {
	status = strings.TrimSpace(status)
	if !domain.ValidTeacherStatus(status) {
		return nil, domain.NewDomainError("Estado inválido. Debe ser 'active', 'inactive', 'medical_leave' o 'vacation'.", 400)
	}
	return s.Teachers.UpdateStatus(ctx, id, status, nilIfEmpty(reason), nilIfEmpty(returnDate))
}

func (s AcademicService) DeleteTeacher(ctx context.Context, id string) (bool, error) {
	return s.Teachers.Delete(ctx, id)
}

func (s AcademicService) TeacherAssignments(ctx context.Context, teacherID string) ([]domain.SubjectTeacherAssignment, error) {
	return s.CourseSubject.GetByTeacher(ctx, teacherID)
}

func (s AcademicService) CourseSubjectTeachers(ctx context.Context, courseID string) ([]domain.SubjectTeacherAssignment, error) {
	return s.CourseSubject.GetByCourse(ctx, courseID)
}

// AssignCourseSubjectTeacher mirrors AssignCourseSubjectTeacher: the subject
// must be enabled (subject_applicability) for the course's year+specialty.
func (s AcademicService) AssignCourseSubjectTeacher(ctx context.Context, courseID, subjectID, teacherID string) (domain.SubjectTeacherAssignment, error) {
	if subjectID == "" || teacherID == "" {
		return domain.SubjectTeacherAssignment{}, domain.NewDomainError("Materia y profesor son obligatorios.", 400)
	}
	course, err := s.Courses.GetCourseByID(ctx, courseID)
	if err != nil {
		return domain.SubjectTeacherAssignment{}, err
	}
	if course == nil {
		return domain.SubjectTeacherAssignment{}, domain.NewDomainError("El curso no existe.", 404)
	}
	enabled, err := s.Subjects.GetAll(ctx, &course.GradeYear, &course.SpecialtyID)
	if err != nil {
		return domain.SubjectTeacherAssignment{}, err
	}
	ok := false
	for _, sub := range enabled {
		if sub.ID == subjectID {
			ok = true
			break
		}
	}
	if !ok {
		return domain.SubjectTeacherAssignment{}, domain.NewDomainError(
			"Esa materia no está habilitada para el año/especialidad de este curso. "+
				"Configurá su aplicabilidad desde la sección Materias.", 400)
	}
	return s.CourseSubject.Assign(ctx, courseID, subjectID, teacherID)
}

func (s AcademicService) RemoveCourseSubjectTeacher(ctx context.Context, courseID, subjectID string) (bool, error) {
	return s.CourseSubject.Remove(ctx, courseID, subjectID)
}

func nilIfEmpty(s *string) *string {
	if s == nil {
		return nil
	}
	if strings.TrimSpace(*s) == "" {
		return nil
	}
	return s
}
