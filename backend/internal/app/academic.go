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

func (s AcademicService) ListSubjects(ctx context.Context, gradeYear *int, specialtyID *string) ([]domain.Subject, error) {
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
	return s.Subjects.Create(ctx, name, subjectType)
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
	return s.Applicability.Add(ctx, subjectID, gradeYear, specialtyID)
}

func (s AcademicService) RemoveApplicability(ctx context.Context, id string) (bool, error) {
	return s.Applicability.Remove(ctx, id)
}

func (s AcademicService) ListTeachers(ctx context.Context) ([]domain.Teacher, error) {
	return s.Teachers.GetAll(ctx)
}

func (s AcademicService) CreateTeacher(ctx context.Context, fullName string, email, phone *string) (domain.Teacher, error) {
	fullName = strings.TrimSpace(fullName)
	if fullName == "" {
		return domain.Teacher{}, domain.NewDomainError("El nombre del profesor es obligatorio.", 400)
	}
	return s.Teachers.Create(ctx, fullName, nilIfEmpty(email), nilIfEmpty(phone))
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
