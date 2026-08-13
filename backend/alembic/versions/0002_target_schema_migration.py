"""Target schema baseline (courses/students/workshop_groups/time_slots/schedule_exceptions).

IMPORTANT — read before touching this file again:

This project's dev database was found to ALREADY contain the full
DATABASE_SCHEMA.md target schema (courses, workshop_groups, students,
student_workshop_groups, time_slots, schedule_exceptions, entry_points,
nfc_bracelets, preceptor_courses, preceptor_favorites,
repeating_student_links, devices, users, attendance_records,
early_departures) — column-for-column, constraint-for-constraint, verified
directly against information_schema/pg_catalog. It was applied OUTSIDE of
Alembic (almost certainly by running the `schema.sql` that
DATABASE_SCHEMA.md calls the source of truth, which isn't checked into this
repo), so `alembic_version` had no row for it at all.

An earlier version of this migration tried to DROP and recreate the
catalog-table tables from 0001 assuming that intermediate shape was still
live. It wasn't — the DB was already ahead of both 0001 and that draft of
0002. Both attempts failed partway through (Alembic's transactional DDL
rolled them back cleanly; nothing was lost), which is what surfaced this.

Given that, this migration does NOT drop or recreate anything. It only
CREATE TABLE IF NOT EXISTS / DO-guards the 5 tables this pass's backend code
actually owns (courses, workshop_groups, students, student_workshop_groups,
time_slots, schedule_exceptions), so that running `alembic upgrade head`
against a genuinely empty database reproduces this same shape. On the actual
dev DB (which already has these tables) every statement here is a no-op.

The other 9 tables (entry_points, nfc_bracelets, preceptor_courses,
preceptor_favorites, repeating_student_links, devices, users,
attendance_records, early_departures) are NOT created here — they already
exist with the correct shape, but this pass's backend code doesn't fully
own them yet (Users/Devices code in particular still references the OLD
intermediate shape — see PreceptorCourseAssignmentModel/DeviceModel/
UserModel in user_model.py). A future migration should establish a proper
Alembic baseline for those, ideally by importing the real `schema.sql` if
it can be located, rather than hand-reconstructing it here.
"""
from alembic import op


revision = "0002_target_schema"
down_revision = "0001_english_schema"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        DO $$ BEGIN
            CREATE TYPE shift_type AS ENUM ('morning', 'afternoon', 'evening');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN
            CREATE TYPE activity_type AS ENUM ('main_shift', 'workshop', 'after_shift');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;

        CREATE TABLE IF NOT EXISTS courses (
            id            VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            academic_year SMALLINT NOT NULL,
            grade_year    SMALLINT NOT NULL,
            division      SMALLINT NOT NULL,
            specialty     TEXT,
            created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
            CHECK (grade_year BETWEEN 1 AND 7),
            CHECK (division > 0),
            UNIQUE (academic_year, grade_year, division)
        );

        CREATE TABLE IF NOT EXISTS workshop_groups (
            id            VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            academic_year SMALLINT NOT NULL,
            grade_year    SMALLINT NOT NULL,
            group_label   TEXT NOT NULL,
            created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
            CHECK (grade_year BETWEEN 1 AND 7),
            UNIQUE (academic_year, grade_year, group_label)
        );

        CREATE TABLE IF NOT EXISTS students (
            id                    VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            first_name            VARCHAR(100) NOT NULL,
            last_name             VARCHAR(100) NOT NULL,
            document_number       VARCHAR(20) UNIQUE,
            course_id             VARCHAR(36) NOT NULL REFERENCES courses(id),
            is_repeating_student  BOOLEAN NOT NULL DEFAULT FALSE,
            created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        CREATE INDEX IF NOT EXISTS idx_students_course ON students (course_id);

        CREATE TABLE IF NOT EXISTS student_workshop_groups (
            student_id         VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            workshop_group_id  VARCHAR(36) NOT NULL REFERENCES workshop_groups(id) ON DELETE CASCADE,
            PRIMARY KEY (student_id, workshop_group_id)
        );

        CREATE TABLE IF NOT EXISTS time_slots (
            id                      VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            course_id               VARCHAR(36) REFERENCES courses(id) ON DELETE CASCADE,
            workshop_group_id       VARCHAR(36) REFERENCES workshop_groups(id) ON DELETE CASCADE,
            shift                   shift_type NOT NULL,
            activity_type           activity_type NOT NULL DEFAULT 'main_shift',
            day_of_week             SMALLINT NOT NULL,
            start_time              TIME NOT NULL,
            end_time                TIME NOT NULL,
            late_tolerance_minutes  INTEGER NOT NULL DEFAULT 0,
            created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
            CHECK (day_of_week BETWEEN 1 AND 7),
            CHECK (end_time > start_time),
            CHECK (
                (activity_type IN ('main_shift', 'after_shift')
                    AND course_id IS NOT NULL AND workshop_group_id IS NULL)
                OR
                (activity_type = 'workshop'
                    AND workshop_group_id IS NOT NULL AND course_id IS NULL)
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
            reason         TEXT,
            created_by     VARCHAR(36) NOT NULL REFERENCES users(id),
            created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
            UNIQUE (course_id, exception_date)
        );
    """)


def downgrade() -> None:
    """Deliberately unimplemented. This migration doesn't know whether the 5
    tables it guards were created by it or already existed (they already did,
    on every environment checked so far) — a blind DROP here risks destroying
    a schema this migration didn't create. Reverse manually if you're certain
    your database has no other dependents on these tables."""
    raise NotImplementedError(
        "0002_target_schema downgrade is intentionally not implemented — see docstring."
    )
