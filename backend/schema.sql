-- =====================================================================
-- Automatic Attendance Manager (AAM) — Database schema
-- PostgreSQL. Canonical, hand-applied (no goose). Re-runnable: the block
-- below drops everything first.
--
-- Naming convention: all identifiers in English (per project convention).
--
-- Changes vs. schema (10):
--   * school_settings: -max_division, -max_workshop_groups_per_course;
--                      +current_academic_year, +lunch_start / lunch_end /
--                      lunch_start_fifth_module.
--   * shifts_config: now just an editable LABEL per shift_type (no times —
--     each course sets its own start/end in the Cursos section).
--   * shift_breaks: reseeded with the real break times (morning ×2,
--     afternoon ×2, evening ×2).
--   * NEW year_structure: divisions allowed per grade_year.
--   * NEW division_workshop_structure: workshop groups allowed per
--     (grade_year, division).
--   * enforce_workshop_groups_limit: reads division_workshop_structure
--     instead of the removed global setting.
-- =====================================================================

-- This file is UTF-8. Force the client encoding so the accented seed data
-- (María, Programación, Mañana…) loads correctly regardless of how psql is run
-- (Windows psql otherwise assumes WIN1252 and double-encodes it).
SET client_encoding TO 'UTF8';

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- for gen_random_uuid()

-- ---------------------------------------------------------------------
-- Clean slate
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS
    early_departures,
    attendance_records,
    preceptor_favorites,
    course_preceptor_temp_assignments,
    course_preceptors,
    repeating_student_links,
    nfc_bracelets,
    students,
    class_periods,
    schedule_exceptions,
    time_slots,
    shift_breaks,
    shifts_config,
    course_subject_teachers,
    teachers,
    subject_applicability,
    subjects,
    division_workshop_structure,
    workshop_groups,
    courses,
    year_structure,
    school_settings,
    specialties,
    devices,
    entry_points,
    users
    CASCADE;

DROP FUNCTION IF EXISTS set_updated_at CASCADE;
DROP FUNCTION IF EXISTS enforce_basic_cycle_specialty CASCADE;
DROP FUNCTION IF EXISTS enforce_basic_cycle_specialty_subject CASCADE;
DROP FUNCTION IF EXISTS enforce_course_subject_applicability CASCADE;
DROP FUNCTION IF EXISTS enforce_class_period_workshop_group_course CASCADE;
DROP FUNCTION IF EXISTS enforce_class_period_subject_type_context CASCADE;
DROP FUNCTION IF EXISTS enforce_workshop_groups_limit CASCADE;
DROP FUNCTION IF EXISTS enforce_class_period_no_shift_break_overlap CASCADE;

DROP TYPE IF EXISTS
    attendance_source,
    subject_type,
    period_type,
    attendance_status,
    activity_type,
    shift_type,
    user_role
    CASCADE;

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------

-- jefe_preceptores: puede asignar/reasignar preceptores a cursos (permanente
-- y temporal) para CUALQUIER curso, no solo los propios. No tiene los demás
-- permisos de `principal` (no crea cursos, usuarios, ni toca configuración).
CREATE TYPE user_role AS ENUM ('principal', 'jefe_preceptores', 'preceptor');

CREATE TYPE shift_type AS ENUM ('morning', 'afternoon', 'evening');

-- turno/taller/contraturno: what kind of activity a time slot belongs to
CREATE TYPE activity_type AS ENUM ('main_shift', 'workshop', 'after_shift');

CREATE TYPE attendance_status AS ENUM (
    'present',
    'late',
    'absent',
    'absent_with_presence',     -- entered >1h late; counts as absent but entry is logged
    'non_computable_absence'    -- does not affect the student's attendance_rate (RITE)
);

CREATE TYPE attendance_source AS ENUM ('nfc', 'qr', 'manual');

-- período dentro del horario académico detallado de un curso (class_periods)
CREATE TYPE period_type AS ENUM ('class', 'recess', 'lunch');

-- tipo fijo de una materia: curricular (turno principal) o taller (contraturno)
CREATE TYPE subject_type AS ENUM ('curricular', 'workshop');

-- ---------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    full_name       TEXT NOT NULL,
    role            user_role NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_by      UUID REFERENCES users(id), -- accounts are created exclusively by principal
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- entry_points and devices (ESP32 readers) — one API key per device
-- ---------------------------------------------------------------------

CREATE TABLE entry_points (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    location        TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_point_id  UUID NOT NULL REFERENCES entry_points(id),
    name            TEXT NOT NULL,
    api_key         TEXT NOT NULL UNIQUE, -- static, individual per device
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ
);

-- ---------------------------------------------------------------------
-- specialties: catálogo (Programación, Construcciones, Electrónica, Ciclo
-- Básico). "Ciclo Básico" es la única con is_basic_cycle = true — se asigna
-- automáticamente a cursos de 1ro a 3ro (ver trigger). No se gestiona desde
-- Configuración; se elige al crear el curso en la sección Cursos.
-- ---------------------------------------------------------------------

CREATE TABLE specialties (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE,
    is_basic_cycle  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO specialties (name, is_basic_cycle) VALUES
    ('Programación', FALSE),
    ('Construcciones', FALSE),
    ('Electrónica', FALSE),
    ('Ciclo Básico', TRUE);

-- ---------------------------------------------------------------------
-- school_settings: fila única de configuración general.
--   * max_grade_year: cantidad de años de cursada (1..N). Editable desde
--     Configuración > Cursos.
--   * current_academic_year: año lectivo activo. Editable desde
--     Configuración > Cursos. La base NO se vacía sola a fin de año.
--   * lunch_*: ventana de almuerzo (no es un recreo). Por defecto
--     11:50–13:10; si un curso de la mañana tiene 5º módulo ese día, el
--     almuerzo arranca 12:50 (lunch_start_fifth_module). Editable desde
--     Configuración > General. Es solo un dato para armar el horario del
--     curso — no lo valida ningún trigger.
--   * *_alert_*: umbrales de la campana de notificaciones.
-- ---------------------------------------------------------------------

CREATE TABLE school_settings (
    id              BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id), -- fuerza fila única
    max_grade_year  SMALLINT NOT NULL DEFAULT 7 CHECK (max_grade_year BETWEEN 1 AND 7),
    current_academic_year SMALLINT NOT NULL DEFAULT 2026 CHECK (current_academic_year BETWEEN 2000 AND 2100),
    lunch_start               TIME NOT NULL DEFAULT '11:50',
    lunch_start_fifth_module  TIME NOT NULL DEFAULT '12:50',
    lunch_end                 TIME NOT NULL DEFAULT '13:10',
    consecutive_absences_alert_threshold SMALLINT NOT NULL DEFAULT 3 CHECK (consecutive_absences_alert_threshold > 0),
    preceptor_temp_assignment_alert_days SMALLINT NOT NULL DEFAULT 2 CHECK (preceptor_temp_assignment_alert_days >= 0),
    schedule_exception_alert_days        SMALLINT NOT NULL DEFAULT 2 CHECK (schedule_exception_alert_days >= 0),
    CONSTRAINT ck_school_settings_lunch_order       CHECK (lunch_start < lunch_end),
    CONSTRAINT ck_school_settings_lunch_fifth_order CHECK (lunch_start_fifth_module < lunch_end)
);

INSERT INTO school_settings DEFAULT VALUES;

-- ---------------------------------------------------------------------
-- year_structure: cuántas divisiones puede tener cada año de cursada.
-- Una fila por grade_year (1..7). No crea cursos — solo dice cuántas
-- opciones de división se ofrecen al crear un curso de ese año.
-- Editable desde Configuración > Cursos.
-- ---------------------------------------------------------------------

CREATE TABLE year_structure (
    grade_year      SMALLINT PRIMARY KEY CHECK (grade_year BETWEEN 1 AND 7),
    division_count  SMALLINT NOT NULL CHECK (division_count > 0)
);

INSERT INTO year_structure (grade_year, division_count) VALUES
    (1, 2), (2, 1), (3, 1), (4, 2), (5, 1), (6, 1), (7, 1);

-- ---------------------------------------------------------------------
-- division_workshop_structure: cuántos grupos de taller (A, B, C...) puede
-- tener el contraturno de un curso puntual, por (grade_year, division).
-- 0 = sin taller (típico de 1ro a 3ro). Editable desde Configuración >
-- Cursos. Lo hace cumplir enforce_workshop_groups_limit.
-- ---------------------------------------------------------------------

CREATE TABLE division_workshop_structure (
    grade_year           SMALLINT NOT NULL CHECK (grade_year BETWEEN 1 AND 7),
    division             SMALLINT NOT NULL CHECK (division > 0),
    workshop_group_count SMALLINT NOT NULL DEFAULT 0 CHECK (workshop_group_count >= 0),
    PRIMARY KEY (grade_year, division)
);

INSERT INTO division_workshop_structure (grade_year, division, workshop_group_count) VALUES
    (1, 1, 0), (1, 2, 0),
    (2, 1, 0),
    (3, 1, 0),
    (4, 1, 2), (4, 2, 1),
    (5, 1, 1),
    (6, 1, 1),
    (7, 1, 1);

-- ---------------------------------------------------------------------
-- shifts_config: etiqueta editable de cada turno. Filas FIJAS (una por
-- valor del enum shift_type). Sin horarios — el inicio/fin de cada turno
-- varía por curso y se maneja en la sección Cursos. Solo se puede editar
-- el texto (Configuración > General).
-- ---------------------------------------------------------------------

CREATE TABLE shifts_config (
    shift   shift_type PRIMARY KEY,
    label   TEXT NOT NULL
);

INSERT INTO shifts_config (shift, label) VALUES
    ('morning',   'Mañana'),
    ('afternoon', 'Tarde'),
    ('evening',   'Vespertino');

-- ---------------------------------------------------------------------
-- shift_breaks: recreos fijos por turno (bells de toda la escuela). Un
-- turno puede tener varios. Editable desde Configuración > General. Se usan
-- para validar que ningún período de clase se superponga con un recreo del
-- turno correspondiente (ver trigger tras CREATE TABLE class_periods).
-- ---------------------------------------------------------------------

CREATE TABLE shift_breaks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift           shift_type NOT NULL,
    label           TEXT NOT NULL DEFAULT 'Recreo',
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    CHECK (end_time > start_time)
);

CREATE INDEX idx_shift_breaks_shift ON shift_breaks(shift);

INSERT INTO shift_breaks (shift, label, start_time, end_time) VALUES
    ('morning',   'Recreo 1', '09:30', '09:40'),
    ('morning',   'Recreo 2', '10:40', '10:50'),
    ('afternoon', 'Recreo 1', '15:10', '15:20'),
    ('afternoon', 'Recreo 2', '16:20', '16:30'),
    ('evening',   'Recreo 1', '19:50', '20:00'),
    ('evening',   'Recreo 2', '20:50', '21:00');

-- ---------------------------------------------------------------------
-- courses: academic_year + grade_year + division  ->  "1ro 2da (2026)"
-- ---------------------------------------------------------------------

CREATE TABLE courses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    academic_year   SMALLINT NOT NULL,
    grade_year      SMALLINT NOT NULL CHECK (grade_year BETWEEN 1 AND 7),
    division        SMALLINT NOT NULL CHECK (division > 0),
    specialty_id    UUID NOT NULL REFERENCES specialties(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (academic_year, grade_year, division)
);

-- 1ro a 3ro = SIEMPRE "Ciclo Básico"; 4to en adelante = NUNCA "Ciclo Básico".
CREATE OR REPLACE FUNCTION enforce_basic_cycle_specialty()
RETURNS TRIGGER AS $$
DECLARE
    v_is_basic BOOLEAN;
BEGIN
    SELECT is_basic_cycle INTO v_is_basic FROM specialties WHERE id = NEW.specialty_id;

    IF NEW.grade_year <= 3 AND NOT COALESCE(v_is_basic, FALSE) THEN
        RAISE EXCEPTION 'Cursos de 1ro a 3ro deben tener la especialidad "Ciclo Básico" (grade_year=%).', NEW.grade_year;
    ELSIF NEW.grade_year >= 4 AND COALESCE(v_is_basic, FALSE) THEN
        RAISE EXCEPTION 'Cursos de 4to en adelante no pueden tener la especialidad "Ciclo Básico" (grade_year=%).', NEW.grade_year;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_courses_basic_cycle_specialty
    BEFORE INSERT OR UPDATE ON courses
    FOR EACH ROW EXECUTE FUNCTION enforce_basic_cycle_specialty();

-- workshop_groups: subdivisión interna de UN curso puntual para el taller
-- del contraturno. No se comparte entre cursos.
CREATE TABLE workshop_groups (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    group_label     TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (course_id, group_label)
);

CREATE INDEX idx_workshop_groups_course ON workshop_groups(course_id);

-- Hace cumplir division_workshop_structure.workshop_group_count para la
-- (grade_year, division) del curso. Solo en INSERT (renombrar un grupo no
-- dispara el chequeo de cantidad).
CREATE OR REPLACE FUNCTION enforce_workshop_groups_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_grade_year SMALLINT;
    v_division   SMALLINT;
    v_max        SMALLINT;
    v_current    INTEGER;
BEGIN
    SELECT grade_year, division INTO v_grade_year, v_division
    FROM courses WHERE id = NEW.course_id;

    SELECT workshop_group_count INTO v_max
    FROM division_workshop_structure
    WHERE grade_year = v_grade_year AND division = v_division;

    v_max := COALESCE(v_max, 0);

    SELECT COUNT(*) INTO v_current
    FROM workshop_groups
    WHERE course_id = NEW.course_id;

    IF v_current >= v_max THEN
        RAISE EXCEPTION 'El curso %ro %da permite hasta % grupo(s) de taller (Configuración → Cursos).',
            v_grade_year, v_division, v_max;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_workshop_groups_limit
    BEFORE INSERT ON workshop_groups
    FOR EACH ROW EXECUTE FUNCTION enforce_workshop_groups_limit();

-- ---------------------------------------------------------------------
-- subjects (materias) y teachers (profesores): catálogo reutilizable.
-- No se gestionan desde Configuración; sus pantallas propias del panel.
-- ---------------------------------------------------------------------

CREATE TABLE subjects (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE,
    subject_type    subject_type NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE subject_applicability (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id      UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    grade_year      SMALLINT NOT NULL CHECK (grade_year BETWEEN 1 AND 7),
    specialty_id    UUID NOT NULL REFERENCES specialties(id),
    UNIQUE (subject_id, grade_year, specialty_id)
);

CREATE INDEX idx_subject_applicability_subject ON subject_applicability(subject_id);
CREATE INDEX idx_subject_applicability_lookup ON subject_applicability(grade_year, specialty_id);

CREATE OR REPLACE FUNCTION enforce_basic_cycle_specialty_subject()
RETURNS TRIGGER AS $$
DECLARE
    v_is_basic BOOLEAN;
BEGIN
    SELECT is_basic_cycle INTO v_is_basic FROM specialties WHERE id = NEW.specialty_id;

    IF NEW.grade_year <= 3 AND NOT COALESCE(v_is_basic, FALSE) THEN
        RAISE EXCEPTION 'Una materia para 1ro a 3ro debe asociarse a la especialidad "Ciclo Básico" (grade_year=%).', NEW.grade_year;
    ELSIF NEW.grade_year >= 4 AND COALESCE(v_is_basic, FALSE) THEN
        RAISE EXCEPTION 'Una materia para 4to en adelante no puede asociarse a "Ciclo Básico" (grade_year=%).', NEW.grade_year;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_subject_applicability_basic_cycle
    BEFORE INSERT OR UPDATE ON subject_applicability
    FOR EACH ROW EXECUTE FUNCTION enforce_basic_cycle_specialty_subject();

CREATE TABLE teachers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name       TEXT NOT NULL,
    email           TEXT,
    phone           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE course_subject_teachers (
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    subject_id      UUID NOT NULL REFERENCES subjects(id),
    teacher_id      UUID NOT NULL REFERENCES teachers(id),
    PRIMARY KEY (course_id, subject_id)
);

CREATE INDEX idx_course_subject_teachers_course ON course_subject_teachers(course_id);

CREATE OR REPLACE FUNCTION enforce_course_subject_applicability()
RETURNS TRIGGER AS $$
DECLARE
    v_grade_year   SMALLINT;
    v_specialty_id UUID;
    v_exists       BOOLEAN;
BEGIN
    SELECT grade_year, specialty_id INTO v_grade_year, v_specialty_id
    FROM courses WHERE id = NEW.course_id;

    SELECT EXISTS (
        SELECT 1 FROM subject_applicability
        WHERE subject_id = NEW.subject_id
          AND grade_year = v_grade_year
          AND specialty_id = v_specialty_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'La materia (%) no está habilitada para el año/especialidad de este curso.', NEW.subject_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_course_subject_teachers_applicability
    BEFORE INSERT OR UPDATE ON course_subject_teachers
    FOR EACH ROW EXECUTE FUNCTION enforce_course_subject_applicability();

-- ---------------------------------------------------------------------
-- time slots and schedule exceptions
-- ---------------------------------------------------------------------

CREATE TABLE time_slots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id         UUID REFERENCES courses(id) ON DELETE CASCADE,
    workshop_group_id UUID REFERENCES workshop_groups(id) ON DELETE CASCADE,
    shift           shift_type NOT NULL,
    activity_type   activity_type NOT NULL DEFAULT 'main_shift',
    day_of_week     SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    late_tolerance_minutes INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_time > start_time),
    CHECK (
        (activity_type = 'workshop' AND workshop_group_id IS NOT NULL AND course_id IS NULL)
        OR
        (activity_type IN ('main_shift', 'after_shift') AND course_id IS NOT NULL AND workshop_group_id IS NULL)
    )
);

CREATE INDEX idx_time_slots_course ON time_slots(course_id);
CREATE INDEX idx_time_slots_workshop_group ON time_slots(workshop_group_id);

CREATE TABLE schedule_exceptions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    exception_date  DATE NOT NULL,
    start_time      TIME,
    end_time        TIME,
    reason          TEXT,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (course_id, exception_date)
);

-- ---------------------------------------------------------------------
-- class_periods: horario académico DETALLADO día por día de un curso.
-- ---------------------------------------------------------------------

CREATE TABLE class_periods (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    workshop_group_id UUID REFERENCES workshop_groups(id) ON DELETE CASCADE,
    day_of_week     SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    shift           shift_type NOT NULL,
    period_order    SMALLINT NOT NULL,
    period_type     period_type NOT NULL,
    subject_id      UUID REFERENCES subjects(id),
    teacher_id      UUID REFERENCES teachers(id),
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    is_fifth_module BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (end_time > start_time),
    CHECK (
        (period_type = 'class' AND subject_id IS NOT NULL)
        OR
        (period_type IN ('recess', 'lunch') AND subject_id IS NULL AND teacher_id IS NULL)
    )
);

CREATE INDEX idx_class_periods_course ON class_periods(course_id);
CREATE INDEX idx_class_periods_workshop_group ON class_periods(workshop_group_id);

CREATE UNIQUE INDEX idx_class_periods_curricular_unique
    ON class_periods (course_id, day_of_week, shift, period_order)
    WHERE workshop_group_id IS NULL;

CREATE UNIQUE INDEX idx_class_periods_workshop_unique
    ON class_periods (workshop_group_id, day_of_week, shift, period_order)
    WHERE workshop_group_id IS NOT NULL;

CREATE OR REPLACE FUNCTION enforce_class_period_workshop_group_course()
RETURNS TRIGGER AS $$
DECLARE
    v_group_course_id UUID;
BEGIN
    IF NEW.workshop_group_id IS NOT NULL THEN
        SELECT course_id INTO v_group_course_id FROM workshop_groups WHERE id = NEW.workshop_group_id;
        IF v_group_course_id IS DISTINCT FROM NEW.course_id THEN
            RAISE EXCEPTION 'workshop_group_id (%) no pertenece al course_id (%) de este período.', NEW.workshop_group_id, NEW.course_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_class_periods_workshop_group_course
    BEFORE INSERT OR UPDATE ON class_periods
    FOR EACH ROW EXECUTE FUNCTION enforce_class_period_workshop_group_course();

CREATE OR REPLACE FUNCTION enforce_class_period_subject_type_context()
RETURNS TRIGGER AS $$
DECLARE
    v_subject_type subject_type;
BEGIN
    IF NEW.subject_id IS NOT NULL THEN
        SELECT subject_type INTO v_subject_type FROM subjects WHERE id = NEW.subject_id;

        IF v_subject_type = 'curricular' AND NEW.workshop_group_id IS NOT NULL THEN
            RAISE EXCEPTION 'La materia (%) es curricular y no puede usarse en un período de taller.', NEW.subject_id;
        ELSIF v_subject_type = 'workshop' AND NEW.workshop_group_id IS NULL THEN
            RAISE EXCEPTION 'La materia (%) es de taller y no puede usarse en un período curricular.', NEW.subject_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_class_periods_subject_type_context
    BEFORE INSERT OR UPDATE ON class_periods
    FOR EACH ROW EXECUTE FUNCTION enforce_class_period_subject_type_context();

-- No dejar cargar un período de tipo 'class' que se superponga con un recreo
-- (shift_breaks) del mismo turno. Los períodos 'recess'/'lunch' del curso no
-- se validan contra esto.
CREATE OR REPLACE FUNCTION enforce_class_period_no_shift_break_overlap()
RETURNS TRIGGER AS $$
DECLARE
    v_break RECORD;
BEGIN
    IF NEW.period_type = 'class' THEN
        FOR v_break IN
            SELECT label, start_time, end_time
            FROM shift_breaks
            WHERE shift = NEW.shift
              AND NEW.start_time < end_time
              AND NEW.end_time > start_time
        LOOP
            RAISE EXCEPTION 'El horario %-% se superpone con el recreo "%" (%-%) del turno %.',
                NEW.start_time, NEW.end_time, v_break.label, v_break.start_time, v_break.end_time, NEW.shift;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_class_periods_no_shift_break_overlap
    BEFORE INSERT OR UPDATE ON class_periods
    FOR EACH ROW EXECUTE FUNCTION enforce_class_period_no_shift_break_overlap();

-- ---------------------------------------------------------------------
-- students and NFC bracelets
-- ---------------------------------------------------------------------

CREATE TABLE students (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    document_number TEXT UNIQUE,
    birth_date      DATE,
    course_id       UUID NOT NULL REFERENCES courses(id),
    workshop_group_id UUID REFERENCES workshop_groups(id),
    is_repeating_student BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_students_course ON students(course_id);
CREATE INDEX idx_students_workshop_group ON students(workshop_group_id);

CREATE TABLE nfc_bracelets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nfc_uid         TEXT NOT NULL UNIQUE,
    student_id      UUID UNIQUE REFERENCES students(id),
    assigned_by     UUID NOT NULL REFERENCES users(id),
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE repeating_student_links (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id          UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    previous_course_id  UUID NOT NULL REFERENCES courses(id),
    current_course_id   UUID NOT NULL REFERENCES courses(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (student_id, previous_course_id, current_course_id)
);

-- ---------------------------------------------------------------------
-- preceptor <-> course assignment and favorites
-- ---------------------------------------------------------------------

CREATE TABLE course_preceptors (
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    shift           shift_type NOT NULL,
    preceptor_id    UUID NOT NULL REFERENCES users(id),
    PRIMARY KEY (course_id, shift)
);

CREATE TABLE course_preceptor_temp_assignments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    shift           shift_type NOT NULL,
    preceptor_id    UUID NOT NULL REFERENCES users(id),
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    reason          TEXT,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_date >= start_date),
    CHECK (end_date <= (start_date + INTERVAL '1 month')::date)
);

CREATE INDEX idx_course_preceptor_temp_course ON course_preceptor_temp_assignments(course_id);

CREATE TABLE preceptor_favorites (
    preceptor_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id       UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    PRIMARY KEY (preceptor_id, course_id)
);

-- ---------------------------------------------------------------------
-- attendance records + early departures
-- ---------------------------------------------------------------------

CREATE TABLE attendance_records (
    id              CHAR(26) PRIMARY KEY,          -- ULID from device
    student_id      UUID NOT NULL REFERENCES students(id),
    course_id       UUID NOT NULL REFERENCES courses(id),
    workshop_group_id UUID REFERENCES workshop_groups(id),
    time_slot_id    UUID REFERENCES time_slots(id),
    device_id       UUID REFERENCES devices(id),
    registered_by   UUID REFERENCES users(id),
    status          attendance_status NOT NULL,
    source          attendance_source NOT NULL,
    entry_timestamp TIMESTAMPTZ NOT NULL,
    synced_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_attendance_student_date ON attendance_records (student_id, entry_timestamp);
CREATE INDEX idx_attendance_course_date  ON attendance_records (course_id, entry_timestamp);

CREATE TABLE early_departures (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_record_id CHAR(26) NOT NULL REFERENCES attendance_records(id),
    departure_time      TIMESTAMPTZ NOT NULL,
    reason               TEXT NOT NULL,
    registered_by        UUID NOT NULL REFERENCES users(id),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (attendance_record_id)
);

-- ---------------------------------------------------------------------
-- trigger: keep updated_at fresh on users/students
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_students_updated_at
    BEFORE UPDATE ON students
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================================
-- SEED — datos de ejemplo para desarrollo local. UUIDs fijos y legibles.
-- Password de todos los usuarios: "changeme123" (bcrypt cost=10).
-- NO usar contra una base con datos reales.
-- =====================================================================

INSERT INTO users (id, email, password_hash, full_name, role, created_by) VALUES
    ('00000000-0000-0000-0000-000000000001', 'direccion@aam.edu.ar',
     '$2b$10$0c0RtkJHahS8oPbUq4kgtu9yDqH44NGktsfAXv/I0ntGzk1dUPuOq',
     'María Dirección', 'principal', NULL);

INSERT INTO users (id, email, password_hash, full_name, role, created_by) VALUES
    ('00000000-0000-0000-0000-000000000002', 'jefe.preceptores@aam.edu.ar',
     '$2b$10$0c0RtkJHahS8oPbUq4kgtu9yDqH44NGktsfAXv/I0ntGzk1dUPuOq',
     'Jorge Jefe', 'jefe_preceptores', '00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000003', 'ana.preceptora@aam.edu.ar',
     '$2b$10$0c0RtkJHahS8oPbUq4kgtu9yDqH44NGktsfAXv/I0ntGzk1dUPuOq',
     'Ana Preceptora', 'preceptor', '00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000004', 'luis.preceptor@aam.edu.ar',
     '$2b$10$0c0RtkJHahS8oPbUq4kgtu9yDqH44NGktsfAXv/I0ntGzk1dUPuOq',
     'Luis Preceptor', 'preceptor', '00000000-0000-0000-0000-000000000001');

INSERT INTO entry_points (id, name, location) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Puerta principal', 'Acceso frente a la calle'),
    ('10000000-0000-0000-0000-000000000002', 'Entrada taller', 'Playón de talleres');

INSERT INTO devices (id, entry_point_id, name, api_key, is_active) VALUES
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
     'Lector Puerta Principal', 'dev_api_key_puerta_principal_f3a9c2', TRUE),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002',
     'Lector Taller', 'dev_api_key_taller_7b1e6d', TRUE);

INSERT INTO courses (id, academic_year, grade_year, division, specialty_id) VALUES
    ('30000000-0000-0000-0000-000000000001', 2026, 1, 1, (SELECT id FROM specialties WHERE name = 'Ciclo Básico')),
    ('30000000-0000-0000-0000-000000000002', 2026, 1, 2, (SELECT id FROM specialties WHERE name = 'Ciclo Básico')),
    ('30000000-0000-0000-0000-000000000003', 2026, 2, 1, (SELECT id FROM specialties WHERE name = 'Ciclo Básico')),
    ('30000000-0000-0000-0000-000000000004', 2026, 3, 1, (SELECT id FROM specialties WHERE name = 'Ciclo Básico')),
    ('30000000-0000-0000-0000-000000000005', 2026, 4, 1, (SELECT id FROM specialties WHERE name = 'Programación')),
    ('30000000-0000-0000-0000-000000000006', 2026, 4, 2, (SELECT id FROM specialties WHERE name = 'Electrónica')),
    ('30000000-0000-0000-0000-000000000007', 2026, 5, 1, (SELECT id FROM specialties WHERE name = 'Programación')),
    ('30000000-0000-0000-0000-000000000008', 2026, 6, 1, (SELECT id FROM specialties WHERE name = 'Construcciones')),
    ('30000000-0000-0000-0000-000000000009', 2026, 7, 1, (SELECT id FROM specialties WHERE name = 'Construcciones'));

INSERT INTO workshop_groups (id, course_id, group_label) VALUES
    ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000005', 'A'),
    ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000005', 'B'),
    ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000006', 'A'),
    ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000007', 'A'),
    ('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000008', 'A'),
    ('40000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000009', 'A');

INSERT INTO subjects (id, name, subject_type) VALUES
    ('50000000-0000-0000-0000-000000000001', 'Matemática', 'curricular'),
    ('50000000-0000-0000-0000-000000000002', 'Lengua y Literatura', 'curricular'),
    ('50000000-0000-0000-0000-000000000003', 'Física', 'curricular'),
    ('50000000-0000-0000-0000-000000000004', 'Programación I', 'workshop'),
    ('50000000-0000-0000-0000-000000000005', 'Electrónica Aplicada', 'workshop'),
    ('50000000-0000-0000-0000-000000000006', 'Construcciones I', 'workshop');

INSERT INTO subject_applicability (subject_id, grade_year, specialty_id) VALUES
    ('50000000-0000-0000-0000-000000000001', 1, (SELECT id FROM specialties WHERE name = 'Ciclo Básico')),
    ('50000000-0000-0000-0000-000000000001', 4, (SELECT id FROM specialties WHERE name = 'Programación')),
    ('50000000-0000-0000-0000-000000000001', 4, (SELECT id FROM specialties WHERE name = 'Electrónica')),
    ('50000000-0000-0000-0000-000000000002', 1, (SELECT id FROM specialties WHERE name = 'Ciclo Básico')),
    ('50000000-0000-0000-0000-000000000003', 2, (SELECT id FROM specialties WHERE name = 'Ciclo Básico')),
    ('50000000-0000-0000-0000-000000000004', 4, (SELECT id FROM specialties WHERE name = 'Programación')),
    ('50000000-0000-0000-0000-000000000005', 4, (SELECT id FROM specialties WHERE name = 'Electrónica')),
    ('50000000-0000-0000-0000-000000000006', 6, (SELECT id FROM specialties WHERE name = 'Construcciones'));

INSERT INTO teachers (id, full_name, email, phone) VALUES
    ('60000000-0000-0000-0000-000000000001', 'Carlos Gómez', 'carlos.gomez@aam.edu.ar', '11-5555-0001'),
    ('60000000-0000-0000-0000-000000000002', 'Marina Ruiz', 'marina.ruiz@aam.edu.ar', '11-5555-0002'),
    ('60000000-0000-0000-0000-000000000003', 'Diego Fernández', 'diego.fernandez@aam.edu.ar', '11-5555-0003');

INSERT INTO course_subject_teachers (course_id, subject_id, teacher_id) VALUES
    ('30000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001'),
    ('30000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002'),
    ('30000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001'),
    ('30000000-0000-0000-0000-000000000005', '50000000-0000-0000-0000-000000000004', '60000000-0000-0000-0000-000000000003'),
    ('30000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001'),
    ('30000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000005', '60000000-0000-0000-0000-000000000003');

INSERT INTO time_slots (course_id, workshop_group_id, shift, activity_type, day_of_week, start_time, end_time, late_tolerance_minutes) VALUES
    ('30000000-0000-0000-0000-000000000001', NULL, 'morning', 'main_shift', 1, '07:30', '11:50', 10),
    ('30000000-0000-0000-0000-000000000001', NULL, 'morning', 'main_shift', 2, '07:30', '11:50', 10),
    ('30000000-0000-0000-0000-000000000005', NULL, 'morning', 'main_shift', 1, '07:30', '11:50', 10);

INSERT INTO time_slots (course_id, workshop_group_id, shift, activity_type, day_of_week, start_time, end_time, late_tolerance_minutes) VALUES
    (NULL, '40000000-0000-0000-0000-000000000001', 'afternoon', 'workshop', 2, '13:10', '17:30', 5);

-- class_periods — 1ro 1ra, lunes a la mañana. Los 'class' NO se superponen
-- con los recreos del turno morning (09:30-09:40 y 10:40-10:50).
INSERT INTO class_periods (course_id, workshop_group_id, day_of_week, shift, period_order, period_type, subject_id, teacher_id, start_time, end_time) VALUES
    ('30000000-0000-0000-0000-000000000001', NULL, 1, 'morning', 1, 'class',  '50000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '07:30', '09:30'),
    ('30000000-0000-0000-0000-000000000001', NULL, 1, 'morning', 2, 'recess', NULL, NULL, '09:30', '09:40'),
    ('30000000-0000-0000-0000-000000000001', NULL, 1, 'morning', 3, 'class',  '50000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000002', '09:40', '10:40'),
    ('30000000-0000-0000-0000-000000000001', NULL, 1, 'morning', 4, 'recess', NULL, NULL, '10:40', '10:50'),
    ('30000000-0000-0000-0000-000000000001', NULL, 1, 'morning', 5, 'class',  '50000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '10:50', '11:50');

INSERT INTO students (id, first_name, last_name, document_number, birth_date, course_id, workshop_group_id, is_repeating_student) VALUES
    ('70000000-0000-0000-0000-000000000001', 'Lucas', 'González',  '55123456', '2013-03-14', '30000000-0000-0000-0000-000000000001', NULL, FALSE),
    ('70000000-0000-0000-0000-000000000002', 'Ana',   'Ferreyra',  '55123457', '2013-06-02', '30000000-0000-0000-0000-000000000001', NULL, FALSE),
    ('70000000-0000-0000-0000-000000000003', 'Diego', 'Romero',    '54987321', '2012-11-20', '30000000-0000-0000-0000-000000000003', NULL, TRUE),
    ('70000000-0000-0000-0000-000000000004', 'Valentina', 'Torres','53445566', '2010-01-30', '30000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000001', FALSE),
    ('70000000-0000-0000-0000-000000000005', 'Martín', 'Suárez',   '53445567', '2010-04-18', '30000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000002', FALSE),
    ('70000000-0000-0000-0000-000000000006', 'Sofía',  'Acosta',   '52998877', '2009-09-09', '30000000-0000-0000-0000-000000000006', '40000000-0000-0000-0000-000000000003', FALSE);

INSERT INTO nfc_bracelets (nfc_uid, student_id, assigned_by, is_active) VALUES
    ('04A1B2C3D4E5F6', '70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', TRUE),
    ('04A1B2C3D4E5F7', '70000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', TRUE),
    ('04A1B2C3D4E5F8', '70000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', TRUE);

INSERT INTO repeating_student_links (student_id, previous_course_id, current_course_id) VALUES
    ('70000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000004');

INSERT INTO course_preceptors (course_id, shift, preceptor_id) VALUES
    ('30000000-0000-0000-0000-000000000001', 'morning', '00000000-0000-0000-0000-000000000003'),
    ('30000000-0000-0000-0000-000000000005', 'morning', '00000000-0000-0000-0000-000000000004');

INSERT INTO course_preceptor_temp_assignments (course_id, shift, preceptor_id, start_date, end_date, reason, created_by) VALUES
    ('30000000-0000-0000-0000-000000000001', 'morning', '00000000-0000-0000-0000-000000000004',
     '2026-08-17', '2026-08-21', 'Licencia por examen', '00000000-0000-0000-0000-000000000002');

INSERT INTO preceptor_favorites (preceptor_id, course_id) VALUES
    ('00000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001');

INSERT INTO attendance_records (id, student_id, course_id, workshop_group_id, device_id, status, source, entry_timestamp) VALUES
    ('01KZNAZ200EHMSYYDFGT1HNFR5', '70000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', NULL, '20000000-0000-0000-0000-000000000001', 'present', 'nfc', '2026-08-10 07:28:00-03'),
    ('01KZNAZ2Z88KM6P26G8FHC1S0P', '70000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', NULL, '20000000-0000-0000-0000-000000000001', 'late',    'nfc', '2026-08-10 07:47:00-03'),
    ('01KZNAZ3YGSEP3AGSQ1AA0E01G', '70000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', NULL, NULL, 'non_computable_absence', 'manual', '2026-08-10 07:30:00-03'),
    ('01KZNAZ4XRPFBYGZ1TC2SZ0SPY', '70000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000005', NULL, '20000000-0000-0000-0000-000000000001', 'present', 'nfc', '2026-08-10 07:29:00-03'),
    ('01KZNAZ5X0850GGNZD220DCBKR', '70000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000005', NULL, '20000000-0000-0000-0000-000000000001', 'absent_with_presence', 'nfc', '2026-08-10 08:52:00-03');

INSERT INTO attendance_records (id, student_id, course_id, registered_by, status, source, entry_timestamp) VALUES
    ('01KZNAZ6W8E2KJW7467280X8FW', '70000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000003', 'absent', 'manual', '2026-08-10 07:30:00-03');

INSERT INTO early_departures (attendance_record_id, departure_time, reason, registered_by) VALUES
    ('01KZNAZ2Z88KM6P26G8FHC1S0P', '2026-08-10 10:15:00-03', 'Turno médico', '00000000-0000-0000-0000-000000000003');
