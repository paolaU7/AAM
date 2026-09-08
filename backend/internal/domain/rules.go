package domain

import (
	"fmt"
	"time"
)

// DateLayout is the wire/date-only format used across DTOs and params.
const DateLayout = "2006-01-02"

// AddOneCalendarMonth replicates Postgres `(d + INTERVAL '1 month')::date`:
// same day of the next month, clamped to that month's last valid day
// (e.g. 31 Jan -> 28/29 Feb). Input and output are "YYYY-MM-DD".
func AddOneCalendarMonth(date string) (string, error) {
	d, err := time.Parse(DateLayout, date)
	if err != nil {
		return "", Errorf("Fecha inválida: %q.", date)
	}
	year, month := d.Year(), int(d.Month())
	if month == 12 {
		year, month = year+1, 1
	} else {
		month++
	}
	lastDay := time.Date(year, time.Month(month)+1, 0, 0, 0, 0, 0, time.UTC).Day()
	day := d.Day()
	if day > lastDay {
		day = lastDay
	}
	return time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.UTC).Format(DateLayout), nil
}

// ValidateDimensions checks grade_year (1..7) and division (>0), matching
// _validate_dimensions in the Python course use case.
func ValidateDimensions(gradeYear, division int) error {
	if gradeYear < 1 || gradeYear > 7 {
		return NewDomainError("El año de cursada debe estar entre 1 y 7.", 400)
	}
	if division < 1 {
		return NewDomainError("La división debe ser mayor a 0.", 400)
	}
	return nil
}

// ValidateBasicCycleSpecialty is the app-side mirror of the DB trigger
// `enforce_basic_cycle_specialty`: 1ro-3ro must use "Ciclo Básico", 4to and up
// must not. `subject` is the phrasing switch so the messages match the Python
// (course vs. subject-applicability contexts).
func ValidateBasicCycleSpecialty(sp *Specialty, gradeYear int, forSubject bool) error {
	if sp == nil {
		return NewDomainError("La especialidad seleccionada no existe.", 400)
	}
	if gradeYear <= 3 && !sp.IsBasicCycle {
		if forSubject {
			return NewDomainError(`Los años 1ro a 3ro deben habilitarse con la especialidad "Ciclo Básico".`, 400)
		}
		return NewDomainError(`Los cursos de 1ro a 3ro deben tener la especialidad "Ciclo Básico".`, 400)
	}
	if gradeYear >= 4 && sp.IsBasicCycle {
		if forSubject {
			return NewDomainError(`Los años 4to en adelante no pueden habilitarse con "Ciclo Básico".`, 400)
		}
		return NewDomainError(`Los cursos de 4to en adelante no pueden tener la especialidad "Ciclo Básico".`, 400)
	}
	return nil
}

// ValidateDayOfWeek checks the ISO 1..7 range.
func ValidateDayOfWeek(d int) error {
	if d < 1 || d > 7 {
		return NewDomainError("day_of_week debe estar entre 1 y 7.", 400)
	}
	return nil
}

// ValidateTimeOrder checks end > start for zero-padded "HH:MM[:SS]" strings
// (lexical comparison is correct for that format).
func ValidateTimeOrder(start, end string) error {
	if end <= start {
		return NewDomainError("La hora de fin debe ser posterior a la de inicio.", 400)
	}
	return nil
}

// GradeYearOrdinal / DivisionOrdinal render the Spanish ordinals used in the
// composed course label ("4to 2da (2026)"). Ported from course_repository_impl.py.
var gradeYearOrdinals = map[int]string{1: "1ro", 2: "2do", 3: "3ro", 4: "4to", 5: "5to", 6: "6to", 7: "7mo"}
var divisionOrdinals = map[int]string{
	1: "1ra", 2: "2da", 3: "3ra", 4: "4ta", 5: "5ta",
	6: "6ta", 7: "7ma", 8: "8va", 9: "9na", 10: "10ma",
}

func GradeYearOrdinal(y int) string {
	if s, ok := gradeYearOrdinals[y]; ok {
		return s
	}
	return fmt.Sprintf("%dto", y)
}

func DivisionOrdinal(d int) string {
	if s, ok := divisionOrdinals[d]; ok {
		return s
	}
	return fmt.Sprintf("%dra", d)
}

// CourseLabel is the composed display name "<grade> <division> (<year>)".
func CourseLabel(academicYear, gradeYear, division int) string {
	return fmt.Sprintf("%s %s (%d)", GradeYearOrdinal(gradeYear), DivisionOrdinal(division), academicYear)
}
