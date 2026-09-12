package domain

import "testing"

func TestGenerarUsername(t *testing.T) {
	cases := []struct{ apellido, nombre, want string }{
		{"Pérez", "María José", "per.mar"},
		{"Gómez", "Ana", "gom.ana"},
		{"Di Núñez", "Juan Ignacio", "din.jua"},
		{"Ur", "Al", "ur.al"},
		{"ÑANDÚ", "ÓSCAR", "nan.osc"},
	}
	for _, c := range cases {
		if got := GenerarUsername(c.apellido, c.nombre); got != c.want {
			t.Errorf("GenerarUsername(%q,%q) = %q, want %q", c.apellido, c.nombre, got, c.want)
		}
	}
}

func TestComputeSubjectShortCode(t *testing.T) {
	cases := []struct {
		name       string
		gradeYears []int
		want       string
	}{
		{"Matemática", []int{1, 6}, "M1r6t"},
		{"Matemática", []int{6}, "M6t"},
		{"Matemática", nil, "M"},
		{"Lengua y Literatura", []int{1}, "LL1r"},
		{"Física", []int{2}, "F2d"},
		{"Programación I", []int{4}, "PI4t"},
		// Mismo año repetido (dos especialidades) no duplica el sufijo.
		{"Matemática", []int{4, 4}, "M4t"},
	}
	for _, c := range cases {
		if got := ComputeSubjectShortCode(c.name, c.gradeYears); got != c.want {
			t.Errorf("ComputeSubjectShortCode(%q, %v) = %q, want %q", c.name, c.gradeYears, got, c.want)
		}
	}
}

func TestAddOneCalendarMonth(t *testing.T) {
	cases := []struct{ in, want string }{
		{"2026-01-15", "2026-02-15"},
		{"2026-01-31", "2026-02-28"}, // clamped
		{"2024-01-31", "2024-02-29"}, // leap year
		{"2026-12-10", "2027-01-10"}, // year rollover
		{"2026-11-30", "2026-12-30"},
	}
	for _, c := range cases {
		got, err := AddOneCalendarMonth(c.in)
		if err != nil {
			t.Fatalf("AddOneCalendarMonth(%q) error: %v", c.in, err)
		}
		if got != c.want {
			t.Errorf("AddOneCalendarMonth(%q) = %q, want %q", c.in, got, c.want)
		}
	}
	if _, err := AddOneCalendarMonth("not-a-date"); err == nil {
		t.Error("expected error for invalid date")
	}
}

func TestValidateBasicCycleSpecialty(t *testing.T) {
	basic := &Specialty{ID: "1", Name: "Ciclo Básico", IsBasicCycle: true}
	prog := &Specialty{ID: "2", Name: "Programación", IsBasicCycle: false}

	if err := ValidateBasicCycleSpecialty(basic, 2, false); err != nil {
		t.Errorf("2nd year + Ciclo Básico should be valid, got %v", err)
	}
	if err := ValidateBasicCycleSpecialty(prog, 2, false); err == nil {
		t.Error("2nd year + non-basic specialty should be rejected")
	}
	if err := ValidateBasicCycleSpecialty(prog, 5, false); err != nil {
		t.Errorf("5th year + Programación should be valid, got %v", err)
	}
	if err := ValidateBasicCycleSpecialty(basic, 5, false); err == nil {
		t.Error("5th year + Ciclo Básico should be rejected")
	}
	if err := ValidateBasicCycleSpecialty(nil, 3, false); err == nil {
		t.Error("nil specialty should be rejected")
	}
}

func TestEstadoRegularidad(t *testing.T) {
	cases := []struct {
		pct  float64
		want EstadoRegularidad
	}{
		{40, RegularidadEnRiesgo},
		{64.9, RegularidadEnRiesgo},
		{65, RegularidadIrregular},
		{74.9, RegularidadIrregular},
		{75, RegularidadRegular},
		{100, RegularidadRegular},
	}
	for _, c := range cases {
		a := Alumno{PorcentajeAsistencia: c.pct}
		if got := a.EstadoRegularidad(); got != c.want {
			t.Errorf("EstadoRegularidad(%.1f) = %q, want %q", c.pct, got, c.want)
		}
	}
}

func TestCourseLabel(t *testing.T) {
	if got := CourseLabel(2026, 4, 2); got != "4to 2da (2026)" {
		t.Errorf("CourseLabel = %q", got)
	}
	if got := CourseLabel(2026, 1, 1); got != "1ro 1ra (2026)" {
		t.Errorf("CourseLabel = %q", got)
	}
}

func TestValidAttendanceStatus(t *testing.T) {
	for _, s := range []string{"present", "late", "absent", "absent_with_presence", "non_computable_absence"} {
		if !ValidAttendanceStatus(s) {
			t.Errorf("%q should be valid", s)
		}
	}
	for _, s := range []string{"", "presente", "PRESENT", "unknown"} {
		if ValidAttendanceStatus(s) {
			t.Errorf("%q should be invalid", s)
		}
	}
}
