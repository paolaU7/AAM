-- +goose Up
-- Baseline schema for AAM, reconstructed from the SQLAlchemy models of the
-- previous Python backend (the source of truth for what the running code and
-- the Flutter app expect). Everything is IF NOT EXISTS / DO-guarded, so on the
-- existing dev database — which already has this schema, applied outside
-- Alembic — every statement is a no-op, while a fresh database gets the full
-- shape. goose tracks its own version in goose_db_version, independent of the
-- old alembic_version table.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE shift_type AS ENUM ('morning', 'afternoon', 'evening');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd
-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE activity_type AS ENUM ('main_shift', 'workshop', 'after_shift');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd
-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE period_type AS ENUM ('class', 'recess', 'lunch');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd
-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE attendance_source AS ENUM ('nfc', 'qr', 'manual');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd
-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE attendance_status AS ENUM
        ('present', 'late', 'absent', 'absent_with_presence', 'non_computable_absence');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd
-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE subject_type AS ENUM ('curricular', 'workshop');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd
-- +goose StatementBegin
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('principal', 'preceptor');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- +goose StatementEnd

CREATE TABLE IF NOT EXISTS specialties (
    id             VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name           TEXT NOT NULL UNIQUE,
    is_basic_cycle BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS school_settings (
    id                                   BOOLEAN PRIMARY KEY DEFAULT TRUE,
    max_grade_year                       SMALLINT NOT NULL DEFAULT 7,
    max_division                         SMALLINT NOT NULL DEFAULT 4,
    consecutive_absences_alert_threshold SMALLINT NOT NULL DEFAULT 3,
    preceptor_temp_assignment_alert_days SMALLINT NOT NULL DEFAULT 2,
    schedule_exception_alert_days        SMALLINT NOT NULL DEFAULT 2,
    CONSTRAINT ck_school_settings_max_grade_year CHECK (max_grade_year BETWEEN 1 AND 7),
    CONSTRAINT ck_school_settings_max_division CHECK (max_division > 0),
    CONSTRAINT ck_school_settings_absences_threshold CHECK (consecutive_absences_alert_threshold > 0),
    CONSTRAINT ck_school_settings_preceptor_alert_days CHECK (preceptor_temp_assignment_alert_days >= 0),
    CONSTRAINT ck_school_settings_exception_alert_days CHECK (schedule_exception_alert_days >= 0),
    CONSTRAINT ck_school_settings_singleton CHECK (id)
);

CREATE TABLE IF NOT EXISTS courses (
    id            VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    academic_year SMALLINT NOT NULL,
    grade_year    SMALLINT NOT NULL,
    division      SMALLINT NOT NULL,
    specialty_id  VARCHAR(36) NOT NULL REFERENCES specialties(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_courses_grade_year CHECK (grade_year BETWEEN 1 AND 7),
    CONSTRAINT ck_courses_division CHECK (division > 0),
    CONSTRAINT uq_courses_dimensions UNIQUE (academic_year, grade_year, division)
);

CREATE TABLE IF NOT EXISTS workshop_groups (
    id          VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    course_id   VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    group_label TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_workshop_groups_course_label UNIQUE (course_id, group_label)
);

CREATE TABLE IF NOT EXISTS students (
    id                   VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    first_name           VARCHAR(100) NOT NULL,
    last_name            VARCHAR(100) NOT NULL,
    document_number      VARCHAR(20) UNIQUE,
    course_id            VARCHAR(36) NOT NULL REFERENCES courses(id),
    workshop_group_id    VARCHAR(36) REFERENCES workshop_groups(id),
    is_repeating_student BOOLEAN NOT NULL DEFAULT FALSE,
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_students_course ON students (course_id);
CREATE INDEX IF NOT EXISTS idx_students_active ON students (is_active);

-- NFC bracelet (NTAG213/215) -> student link, read by the ESP32 device flow.
CREATE TABLE IF NOT EXISTS nfc_bracelets (
    id         VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    tag_uid    VARCHAR(64) NOT NULL UNIQUE,
    student_id VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_nfc_bracelets_student ON nfc_bracelets (student_id);

CREATE TABLE IF NOT EXISTS users (
    id            VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name     VARCHAR(150) NOT NULL,
    role          user_role NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_by    VARCHAR(36) REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS devices (
    id           VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    device_name  VARCHAR(100) NOT NULL UNIQUE,
    location     VARCHAR(150),
    api_key_hash TEXT NOT NULL UNIQUE,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS subjects (
    id           VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name         TEXT NOT NULL UNIQUE,
    subject_type subject_type NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subject_applicability (
    id           VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    subject_id   VARCHAR(36) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    grade_year   SMALLINT NOT NULL,
    specialty_id VARCHAR(36) NOT NULL REFERENCES specialties(id),
    CONSTRAINT ck_subject_applicability_grade_year CHECK (grade_year BETWEEN 1 AND 7)
);

CREATE TABLE IF NOT EXISTS teachers (
    id         VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    full_name  TEXT NOT NULL,
    email      TEXT,
    phone      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS course_subject_teachers (
    course_id  VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    subject_id VARCHAR(36) NOT NULL REFERENCES subjects(id),
    teacher_id VARCHAR(36) NOT NULL REFERENCES teachers(id),
    PRIMARY KEY (course_id, subject_id)
);

CREATE TABLE IF NOT EXISTS class_periods (
    id                VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    course_id         VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    workshop_group_id VARCHAR(36) REFERENCES workshop_groups(id) ON DELETE CASCADE,
    day_of_week       SMALLINT NOT NULL,
    shift             shift_type NOT NULL,
    period_order      SMALLINT NOT NULL,
    period_type       period_type NOT NULL,
    subject_id        VARCHAR(36) REFERENCES subjects(id),
    teacher_id        VARCHAR(36) REFERENCES teachers(id),
    start_time        TIME NOT NULL,
    end_time          TIME NOT NULL,
    is_fifth_module   BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT ck_class_periods_day_of_week CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT ck_class_periods_time_order CHECK (end_time > start_time)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_class_periods_curricular_unique
    ON class_periods (course_id, day_of_week, shift, period_order)
    WHERE workshop_group_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_class_periods_workshop_unique
    ON class_periods (workshop_group_id, day_of_week, shift, period_order)
    WHERE workshop_group_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS course_preceptors (
    course_id    VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    shift        shift_type NOT NULL,
    preceptor_id VARCHAR(36) NOT NULL REFERENCES users(id),
    PRIMARY KEY (course_id, shift)
);

CREATE TABLE IF NOT EXISTS course_preceptor_temp_assignments (
    id           VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    course_id    VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    shift        shift_type NOT NULL,
    preceptor_id VARCHAR(36) NOT NULL REFERENCES users(id),
    start_date   DATE NOT NULL,
    end_date     DATE NOT NULL,
    reason       TEXT,
    created_by   VARCHAR(36) NOT NULL REFERENCES users(id),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_temp_assignment_max_one_month CHECK (end_date <= (start_date + INTERVAL '1 month')::date)
);

CREATE TABLE IF NOT EXISTS time_slots (
    id                     VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    course_id              VARCHAR(36) REFERENCES courses(id) ON DELETE CASCADE,
    workshop_group_id      VARCHAR(36) REFERENCES workshop_groups(id) ON DELETE CASCADE,
    shift                  shift_type NOT NULL,
    activity_type          activity_type NOT NULL DEFAULT 'main_shift',
    day_of_week            SMALLINT NOT NULL,
    start_time             TIME NOT NULL,
    end_time               TIME NOT NULL,
    late_tolerance_minutes INTEGER NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_time_slots_day_of_week CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT ck_time_slots_time_order CHECK (end_time > start_time),
    CONSTRAINT ck_time_slots_course_xor_workshop CHECK (
        (activity_type IN ('main_shift', 'after_shift') AND course_id IS NOT NULL AND workshop_group_id IS NULL)
        OR (activity_type = 'workshop' AND workshop_group_id IS NOT NULL AND course_id IS NULL)
    )
);
CREATE INDEX IF NOT EXISTS idx_time_slots_course ON time_slots (course_id);
CREATE INDEX IF NOT EXISTS idx_time_slots_workshop_group ON time_slots (workshop_group_id);

CREATE TABLE IF NOT EXISTS schedule_exceptions (
    id             VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    course_id      VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    exception_date DATE NOT NULL,
    start_time     TIME,
    end_time       TIME,
    reason         VARCHAR(255),
    created_by     VARCHAR(36) NOT NULL REFERENCES users(id),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_schedule_exceptions_course_date UNIQUE (course_id, exception_date)
);

CREATE TABLE IF NOT EXISTS attendance_records (
    id                CHAR(26) PRIMARY KEY,
    student_id        VARCHAR(36) NOT NULL REFERENCES students(id),
    course_id         VARCHAR(36) NOT NULL REFERENCES courses(id),
    workshop_group_id VARCHAR(36) REFERENCES workshop_groups(id),
    time_slot_id      VARCHAR(36) REFERENCES time_slots(id),
    device_id         VARCHAR(36) REFERENCES devices(id),
    registered_by     VARCHAR(36) REFERENCES users(id),
    source            attendance_source NOT NULL,
    status            attendance_status NOT NULL,
    entry_timestamp   TIMESTAMPTZ NOT NULL,
    synced_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_attendance_student_date ON attendance_records (student_id, entry_timestamp);
CREATE INDEX IF NOT EXISTS idx_attendance_course_date ON attendance_records (course_id, entry_timestamp);

CREATE TABLE IF NOT EXISTS early_departures (
    id                   VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    attendance_record_id CHAR(26) NOT NULL REFERENCES attendance_records(id) ON DELETE CASCADE,
    departure_time       TIMESTAMPTZ NOT NULL,
    reason               VARCHAR(255) NOT NULL,
    registered_by        VARCHAR(36) NOT NULL REFERENCES users(id),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- +goose Down
-- Intentionally minimal: this baseline is written to be a no-op against the
-- pre-existing dev schema, so a blind DROP would be destructive. Reverse
-- manually if you are certain the database has no other dependents.
SELECT 1;
