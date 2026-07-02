"""English schema migration.

Splits the old monolithic `cursos` table into the four course dimensions
(academic_years, divisions, specialties, shifts) + workshop_groups (N:M), and
renames/reshapes the rest of the model to English:

    cursos              -> academic_years / divisions / specialties / shifts
                           + courses + course_workshop_groups
    alumnos             -> students + student_course_enrollments
                           + student_workshop_groups
    usuarios            -> users
    registros_ingreso   -> attendance_records + non_computable_absences

Also creates the remaining new-schema tables: devices,
preceptor_course_assignments, repeating_subjects, schedule_slots,
schedule_exceptions, early_departures.

NOTE ON TYPES: the team's SQLAlchemy models use String(36) for UUID surrogate
keys, so this migration creates those columns as VARCHAR(36) (default
gen_random_uuid()::text) instead of the native UUID type shown in the reference
schema. This keeps the ORM and the database in agreement.

>>> BUSINESS DECISIONS BAKED IN (see project notes / adjust before prod run) <<<
  * shifts.start_time / end_time: the old `turno` enum carried no times.
    Placeholder bands are assigned per turno below (PLACEHOLDER_SHIFT_TIMES).
  * courses with NULL/empty especialidad map to a specialty named
    DEFAULT_SPECIALTY_NAME ('Sin especialidad').
  * academic_years.name is filled with the raw year number as text ('4');
    rename to '4th Year' style afterwards if desired.
  * every migrated enrollment gets enrollment_type='regular' — the old schema
    had no per-student recursante marker to derive it from.
  * alumnos.taller_id -> student_workshop_groups is NOT migrated: taller_id
    referenced the (unknown) `horarios` table, not workshop_groups.
  * attendance_records.id is regenerated as a fresh UUID per old ULID (ULID->UUID
    decoding is not done in SQL); the old 26-char ULID is therefore not preserved.
  * attendance_records.course_id is derived from the student's course at
    migration time (alumnos.curso_id), not from the historical schedule.
  * attendance_records.device_id is left NULL: the old `dispositivos` table has
    no model/known schema to map into `devices`.
  * registros_ingreso.estado = NULL maps to 'absent'.
  * users.username is filled from the old `correo` (email); the old schema had
    no username column.
"""
from alembic import op


# revision identifiers, used by Alembic.
revision = "0001_english_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # 0. Extensions + enum types
    # ------------------------------------------------------------------
    op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')
    op.execute("""
        DO $$ BEGIN
            CREATE TYPE user_role AS ENUM ('direction', 'preceptor');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN
            CREATE TYPE enrollment_type AS ENUM ('regular', 'repeating');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN
            CREATE TYPE activity_type AS ENUM ('regular', 'workshop', 'extended_shift');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN
            CREATE TYPE exception_scope AS ENUM ('single_day', 'week', 'custom_range');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN
            CREATE TYPE attendance_status AS ENUM
                ('present', 'late', 'absent', 'absent_with_presence', 'non_computable');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN
            CREATE TYPE attendance_source AS ENUM ('nfc', 'qr', 'manual');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN
            CREATE TYPE non_computable_reason AS ENUM ('schedule_overlap', 'manual');
        EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    """)

    # ------------------------------------------------------------------
    # 1. New-schema tables (VARCHAR(36) surrogate keys to match the ORM)
    # ------------------------------------------------------------------
    op.execute("""
        CREATE TABLE academic_years (
            id          SMALLSERIAL PRIMARY KEY,
            name        VARCHAR(50) NOT NULL UNIQUE,
            sort_order  SMALLINT    NOT NULL UNIQUE
        );

        CREATE TABLE divisions (
            id    SMALLSERIAL PRIMARY KEY,
            name  VARCHAR(20) NOT NULL UNIQUE
        );

        CREATE TABLE specialties (
            id    SMALLSERIAL PRIMARY KEY,
            name  VARCHAR(100) NOT NULL UNIQUE
        );

        CREATE TABLE shifts (
            id          SMALLSERIAL PRIMARY KEY,
            name        VARCHAR(50) NOT NULL UNIQUE,
            start_time  TIME NOT NULL,
            end_time    TIME NOT NULL
        );

        CREATE TABLE workshop_groups (
            id    SMALLSERIAL PRIMARY KEY,
            name  VARCHAR(100) NOT NULL UNIQUE
        );

        CREATE TABLE courses (
            id                VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            academic_year_id  SMALLINT NOT NULL REFERENCES academic_years(id),
            division_id       SMALLINT NOT NULL REFERENCES divisions(id),
            specialty_id      SMALLINT NOT NULL REFERENCES specialties(id),
            shift_id          SMALLINT NOT NULL REFERENCES shifts(id),
            is_active         BOOLEAN  NOT NULL DEFAULT TRUE,
            created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
            UNIQUE (academic_year_id, division_id, specialty_id, shift_id)
        );
        CREATE INDEX idx_courses_dimensions
            ON courses (academic_year_id, division_id, specialty_id, shift_id);

        CREATE TABLE course_workshop_groups (
            course_id          VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            workshop_group_id  SMALLINT    NOT NULL REFERENCES workshop_groups(id) ON DELETE CASCADE,
            PRIMARY KEY (course_id, workshop_group_id)
        );

        CREATE TABLE users (
            id             VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            username       VARCHAR(50)  NOT NULL UNIQUE,
            password_hash  TEXT         NOT NULL,
            full_name      VARCHAR(150) NOT NULL,
            role           user_role    NOT NULL,
            is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
            created_by     VARCHAR(36) REFERENCES users(id),
            created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
            updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
        );

        CREATE TABLE devices (
            id            VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            device_name   VARCHAR(100) NOT NULL UNIQUE,
            location      VARCHAR(150),
            api_key_hash  TEXT         NOT NULL UNIQUE,
            is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
            created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
            last_seen_at  TIMESTAMPTZ
        );

        CREATE TABLE preceptor_course_assignments (
            user_id      VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            course_id    VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            is_favorite  BOOLEAN NOT NULL DEFAULT FALSE,
            assigned_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (user_id, course_id)
        );

        CREATE TABLE students (
            id           VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            first_name   VARCHAR(100) NOT NULL,
            last_name    VARCHAR(100) NOT NULL,
            national_id  VARCHAR(20)  NOT NULL UNIQUE,
            birth_date   DATE,
            nfc_uid      VARCHAR(64)  UNIQUE,
            qr_code      VARCHAR(64)  UNIQUE,
            is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
            created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
            updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
        );
        CREATE INDEX idx_students_active ON students (is_active);

        CREATE TABLE student_course_enrollments (
            id               VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            student_id       VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            course_id        VARCHAR(36) NOT NULL REFERENCES courses(id),
            enrollment_type  enrollment_type NOT NULL DEFAULT 'regular',
            start_date       DATE NOT NULL DEFAULT CURRENT_DATE,
            end_date         DATE,
            UNIQUE (student_id, course_id, start_date)
        );
        CREATE INDEX idx_enrollments_student ON student_course_enrollments (student_id);
        CREATE INDEX idx_enrollments_course  ON student_course_enrollments (course_id);

        CREATE TABLE student_workshop_groups (
            student_id         VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            workshop_group_id  SMALLINT    NOT NULL REFERENCES workshop_groups(id) ON DELETE CASCADE,
            joined_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (student_id, workshop_group_id)
        );

        CREATE TABLE repeating_subjects (
            id                    VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            student_id            VARCHAR(36) NOT NULL REFERENCES students(id) ON DELETE CASCADE,
            subject_name          VARCHAR(150) NOT NULL,
            origin_academic_year  SMALLINT NOT NULL REFERENCES academic_years(id),
            origin_course_id      VARCHAR(36) REFERENCES courses(id),
            created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        CREATE TABLE schedule_slots (
            id                VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            course_id         VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            activity_type     activity_type NOT NULL DEFAULT 'regular',
            day_of_week       SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
            start_time        TIME NOT NULL,
            end_time          TIME NOT NULL,
            tolerance_minutes SMALLINT NOT NULL DEFAULT 0,
            CHECK (end_time > start_time)
        );
        CREATE INDEX idx_schedule_slots_course ON schedule_slots (course_id);

        CREATE TABLE schedule_exceptions (
            id             VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            course_id      VARCHAR(36) NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
            scope          exception_scope NOT NULL,
            exception_date DATE,
            week_start     DATE,
            range_start    DATE,
            range_end      DATE,
            day_of_week    SMALLINT CHECK (day_of_week BETWEEN 1 AND 7),
            start_time     TIME,
            end_time       TIME,
            reason         VARCHAR(255),
            created_by     VARCHAR(36) NOT NULL REFERENCES users(id),
            created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        CREATE TABLE attendance_records (
            id                VARCHAR(36) PRIMARY KEY,
            student_id        VARCHAR(36) NOT NULL REFERENCES students(id),
            course_id         VARCHAR(36) NOT NULL REFERENCES courses(id),
            schedule_slot_id  VARCHAR(36) REFERENCES schedule_slots(id),
            device_id         VARCHAR(36) REFERENCES devices(id),
            registered_by     VARCHAR(36) REFERENCES users(id),
            source            attendance_source NOT NULL,
            status            attendance_status NOT NULL,
            check_in_time     TIMESTAMPTZ NOT NULL,
            synced_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
            created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        CREATE INDEX idx_attendance_student_date ON attendance_records (student_id, check_in_time);
        CREATE INDEX idx_attendance_course_date  ON attendance_records (course_id, check_in_time);

        CREATE TABLE early_departures (
            id                    VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            attendance_record_id  VARCHAR(36) NOT NULL REFERENCES attendance_records(id) ON DELETE CASCADE,
            departure_time        TIMESTAMPTZ NOT NULL,
            reason                VARCHAR(255) NOT NULL,
            registered_by         VARCHAR(36) NOT NULL REFERENCES users(id),
            created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        CREATE TABLE non_computable_absences (
            id                    VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
            attendance_record_id  VARCHAR(36) NOT NULL REFERENCES attendance_records(id) ON DELETE CASCADE,
            reason_type           non_computable_reason NOT NULL,
            detail                VARCHAR(255),
            registered_by         VARCHAR(36) REFERENCES users(id),
            created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
        );
    """)

    # ------------------------------------------------------------------
    # 2. Data migration from the old Spanish tables (only if they exist).
    #    Robust for fresh installs where there is nothing to migrate.
    # ------------------------------------------------------------------
    op.execute("""
    DO $migrate$
    BEGIN
        IF to_regclass('public.cursos') IS NULL THEN
            RAISE NOTICE 'No legacy `cursos` table found — skipping data migration.';
            RETURN;
        END IF;

        ------------------------------------------------------------------
        -- 2a. Course dimensions
        ------------------------------------------------------------------
        INSERT INTO academic_years (name, sort_order)
        SELECT DISTINCT anio::text, anio FROM cursos
        ON CONFLICT (name) DO NOTHING;

        INSERT INTO divisions (name)
        SELECT DISTINCT division FROM cursos
        ON CONFLICT (name) DO NOTHING;

        INSERT INTO specialties (name)
        SELECT DISTINCT COALESCE(NULLIF(especialidad, ''), 'Sin especialidad') FROM cursos
        ON CONFLICT (name) DO NOTHING;

        -- PLACEHOLDER_SHIFT_TIMES — verify/replace before production.
        INSERT INTO shifts (name, start_time, end_time)
        SELECT DISTINCT turno::text,
               CASE turno::text WHEN 'manana'     THEN TIME '07:30'
                                WHEN 'tarde'      THEN TIME '13:00'
                                WHEN 'vespertino' THEN TIME '18:30'
                                ELSE TIME '08:00' END,
               CASE turno::text WHEN 'manana'     THEN TIME '12:30'
                                WHEN 'tarde'      THEN TIME '18:00'
                                WHEN 'vespertino' THEN TIME '22:30'
                                ELSE TIME '12:00' END
        FROM cursos
        ON CONFLICT (name) DO NOTHING;

        INSERT INTO workshop_groups (name)
        SELECT DISTINCT grupo_taller FROM cursos
        WHERE grupo_taller IS NOT NULL AND grupo_taller <> ''
        ON CONFLICT (name) DO NOTHING;

        ------------------------------------------------------------------
        -- 2b. Courses (combination of the 4 dimensions) + legacy map.
        --     Several old `cursos` rows can collapse into one course
        --     (they differed only by grupo_taller, now an N:M link).
        ------------------------------------------------------------------
        CREATE TEMP TABLE _resolved ON COMMIT DROP AS
        SELECT c.id AS old_id,
               ay.id AS academic_year_id,
               d.id  AS division_id,
               sp.id AS specialty_id,
               sh.id AS shift_id,
               c.activo, c.creado_en
        FROM cursos c
        JOIN academic_years ay ON ay.name = c.anio::text
        JOIN divisions      d  ON d.name  = c.division
        JOIN specialties    sp ON sp.name = COALESCE(NULLIF(c.especialidad, ''), 'Sin especialidad')
        JOIN shifts         sh ON sh.name = c.turno::text;

        INSERT INTO courses (academic_year_id, division_id, specialty_id, shift_id, is_active, created_at)
        SELECT academic_year_id, division_id, specialty_id, shift_id,
               bool_or(activo), min(creado_en)
        FROM _resolved
        GROUP BY academic_year_id, division_id, specialty_id, shift_id
        ON CONFLICT (academic_year_id, division_id, specialty_id, shift_id) DO NOTHING;

        CREATE TEMP TABLE _curso_map ON COMMIT DROP AS
        SELECT r.old_id, co.id AS new_id
        FROM _resolved r
        JOIN courses co
          ON co.academic_year_id = r.academic_year_id
         AND co.division_id      = r.division_id
         AND co.specialty_id     = r.specialty_id
         AND co.shift_id         = r.shift_id;

        -- grupo_taller -> course_workshop_groups link
        INSERT INTO course_workshop_groups (course_id, workshop_group_id)
        SELECT DISTINCT m.new_id, wg.id
        FROM cursos c
        JOIN _curso_map m ON m.old_id = c.id
        JOIN workshop_groups wg ON wg.name = c.grupo_taller
        WHERE c.grupo_taller IS NOT NULL AND c.grupo_taller <> ''
        ON CONFLICT DO NOTHING;

        ------------------------------------------------------------------
        -- 2c. Students + enrollments (+ id map)
        ------------------------------------------------------------------
        IF to_regclass('public.alumnos') IS NOT NULL THEN
            CREATE TEMP TABLE _alumno_map (old_id INT PRIMARY KEY, new_id VARCHAR(36)) ON COMMIT DROP;

            WITH ins AS (
                INSERT INTO students
                    (first_name, last_name, national_id, nfc_uid, qr_code, is_active, created_at, updated_at)
                SELECT nombre, apellido, dni, nfc_uid, qr_token, activo, creado_en, actualizado_en
                FROM alumnos
                RETURNING id, national_id
            )
            INSERT INTO _alumno_map (old_id, new_id)
            SELECT a.id, ins.id FROM ins JOIN alumnos a ON a.dni = ins.national_id;

            -- one enrollment per alumno, enrollment_type='regular' (no legacy source)
            INSERT INTO student_course_enrollments (student_id, course_id, enrollment_type, start_date)
            SELECT am.new_id, cm.new_id, 'regular', a.creado_en::date
            FROM alumnos a
            JOIN _alumno_map am ON am.old_id = a.id
            JOIN _curso_map  cm ON cm.old_id = a.curso_id;

            -- NOTE: alumnos.taller_id -> student_workshop_groups intentionally NOT
            -- migrated (taller_id referenced the unknown `horarios` table).
        END IF;

        ------------------------------------------------------------------
        -- 2d. Users (+ id map)
        ------------------------------------------------------------------
        IF to_regclass('public.usuarios') IS NOT NULL THEN
            CREATE TEMP TABLE _usuario_map (old_id INT PRIMARY KEY, new_id VARCHAR(36)) ON COMMIT DROP;

            WITH ins AS (
                INSERT INTO users (username, password_hash, full_name, role, is_active, created_at, updated_at)
                SELECT correo, password_hash, apellido || ', ' || nombre,
                       (CASE rol::text WHEN 'direccion' THEN 'direction'
                                       WHEN 'preceptor' THEN 'preceptor' END)::user_role,
                       activo, creado_en, actualizado_en
                FROM usuarios
                RETURNING id, username
            )
            INSERT INTO _usuario_map (old_id, new_id)
            SELECT u.id, ins.id FROM ins JOIN usuarios u ON u.correo = ins.username;
        END IF;

        ------------------------------------------------------------------
        -- 2e. Attendance records (+ non-computable absences)
        ------------------------------------------------------------------
        IF to_regclass('public.registros_ingreso') IS NOT NULL
           AND to_regclass('public.alumnos') IS NOT NULL THEN

            -- deterministic new UUID per old ULID (ULID itself is not preserved)
            CREATE TEMP TABLE _registro_map
                (old_ulid VARCHAR(26) PRIMARY KEY, new_id VARCHAR(36) DEFAULT gen_random_uuid()::text)
                ON COMMIT DROP;
            INSERT INTO _registro_map (old_ulid) SELECT ulid FROM registros_ingreso;

            INSERT INTO attendance_records
                (id, student_id, course_id, device_id, registered_by,
                 source, status, check_in_time, synced_at, created_at)
            SELECT rm.new_id,
                   am.new_id,
                   cm.new_id,
                   NULL,                                   -- device mapping unavailable
                   um.new_id,
                   r.metodo::text::attendance_source,
                   (CASE r.estado::text
                        WHEN 'presente'                THEN 'present'
                        WHEN 'tarde'                   THEN 'late'
                        WHEN 'ausente'                 THEN 'absent'
                        WHEN 'ausente_con_permanencia' THEN 'absent_with_presence'
                        WHEN 'falta_no_computable'     THEN 'non_computable'
                        ELSE 'absent' END)::attendance_status,
                   r.registrado_en,
                   COALESCE(r.sincronizado_en, r.registrado_en),
                   r.registrado_en
            FROM registros_ingreso r
            JOIN _registro_map rm ON rm.old_ulid = r.ulid
            JOIN alumnos a        ON a.id = r.alumno_id
            JOIN _alumno_map am   ON am.old_id = r.alumno_id
            JOIN _curso_map  cm   ON cm.old_id = a.curso_id
            LEFT JOIN _usuario_map um ON um.old_id = r.creado_por;

            INSERT INTO non_computable_absences
                (attendance_record_id, reason_type, detail, registered_by)
            SELECT rm.new_id,
                   (CASE WHEN r.no_computable_automatico THEN 'schedule_overlap'
                         ELSE 'manual' END)::non_computable_reason,
                   r.motivo_no_computable,
                   CASE WHEN r.no_computable_automatico THEN NULL ELSE um.new_id END
            FROM registros_ingreso r
            JOIN _registro_map rm ON rm.old_ulid = r.ulid
            LEFT JOIN _usuario_map um ON um.old_id = r.creado_por
            WHERE r.es_falta_no_computable = TRUE;
        END IF;

        ------------------------------------------------------------------
        -- 2f. Drop the old tables + old enum types.
        --     `horarios` and `dispositivos` are intentionally left in place
        --     (unknown schema, no models); drop them manually if obsolete.
        ------------------------------------------------------------------
        DROP TABLE IF EXISTS registros_ingreso;
        DROP TABLE IF EXISTS alumnos;
        DROP TABLE IF EXISTS usuarios;
        DROP TABLE IF EXISTS cursos;

        DROP TYPE IF EXISTS estado_asistencia;
        DROP TYPE IF EXISTS metodo_registro;
        DROP TYPE IF EXISTS tipo_actividad;
        DROP TYPE IF EXISTS rol_usuario;
        DROP TYPE IF EXISTS turno;
    END
    $migrate$;
    """)


def downgrade() -> None:
    """Best-effort structural + core-data reversal.

    Restores the old Spanish tables (cursos, alumnos, usuarios,
    registros_ingreso) and re-migrates the deterministic entities. LOSSY:
    workshop memberships, devices, schedules, enrollment history, early
    departures and the original ULIDs are NOT restored. The recreated old
    tables drop the `horarios`/`dispositivos` foreign keys (those tables may
    no longer exist).
    """
    # 1. Recreate old enum types
    op.execute("""
        DO $$ BEGIN CREATE TYPE turno AS ENUM ('manana','tarde','vespertino');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN CREATE TYPE rol_usuario AS ENUM ('direccion','preceptor');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN CREATE TYPE tipo_actividad AS ENUM ('turno_principal','taller','contraturno');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN CREATE TYPE metodo_registro AS ENUM ('nfc','qr','manual');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$;
        DO $$ BEGIN CREATE TYPE estado_asistencia AS ENUM
            ('presente','tarde','ausente','ausente_con_permanencia','falta_no_computable');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    """)

    # 2. Recreate old tables (without the horarios/dispositivos FKs)
    op.execute("""
        CREATE TABLE IF NOT EXISTS cursos (
            id           SERIAL PRIMARY KEY,
            anio         SMALLINT NOT NULL,
            division     VARCHAR(10) NOT NULL,
            grupo_taller VARCHAR(10) NOT NULL DEFAULT '',
            especialidad VARCHAR(100),
            turno        turno NOT NULL,
            activo       BOOLEAN NOT NULL DEFAULT TRUE,
            creado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
            UNIQUE (anio, division, grupo_taller, turno)
        );
        CREATE TABLE IF NOT EXISTS alumnos (
            id             SERIAL PRIMARY KEY,
            nombre         VARCHAR(255) NOT NULL,
            apellido       VARCHAR(255) NOT NULL,
            dni            VARCHAR(20) NOT NULL UNIQUE,
            curso_id       INTEGER NOT NULL REFERENCES cursos(id),
            nfc_uid        VARCHAR(64) UNIQUE,
            qr_token       VARCHAR(64) UNIQUE,
            taller_id      INTEGER,
            activo         BOOLEAN NOT NULL DEFAULT TRUE,
            creado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
            actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        CREATE TABLE IF NOT EXISTS usuarios (
            id                SERIAL PRIMARY KEY,
            correo            VARCHAR(255) NOT NULL UNIQUE,
            password_hash     VARCHAR(255) NOT NULL,
            rol               rol_usuario NOT NULL,
            nombre            VARCHAR(255) NOT NULL,
            apellido          VARCHAR(255) NOT NULL,
            turno             turno,
            activo            BOOLEAN NOT NULL DEFAULT TRUE,
            clave_generada_en TIMESTAMPTZ,
            creado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
            actualizado_en    TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        CREATE TABLE IF NOT EXISTS registros_ingreso (
            ulid                     VARCHAR(26) PRIMARY KEY,
            alumno_id                INTEGER NOT NULL REFERENCES alumnos(id),
            dispositivo_id           INTEGER,
            tipo_actividad           tipo_actividad NOT NULL DEFAULT 'turno_principal',
            metodo                   metodo_registro NOT NULL,
            registrado_en            TIMESTAMPTZ NOT NULL,
            sincronizado_en          TIMESTAMPTZ,
            creado_por               INTEGER REFERENCES usuarios(id),
            estado                   estado_asistencia,
            es_falta_no_computable   BOOLEAN NOT NULL DEFAULT FALSE,
            motivo_no_computable     TEXT,
            no_computable_automatico BOOLEAN NOT NULL DEFAULT FALSE
        );
    """)

    # 3. Best-effort reverse data migration
    op.execute("""
    DO $rev$
    BEGIN
        IF to_regclass('public.courses') IS NULL THEN
            RETURN;
        END IF;

        -- cursos: one row per (course x linked workshop group), or a single
        -- row with empty grupo_taller when the course has no workshop links.
        CREATE TEMP TABLE _course_rev ON COMMIT DROP AS
        SELECT co.id AS course_uuid,
               NULLIF(regexp_replace(ay.name, '[^0-9]', '', 'g'), '')::smallint AS anio,
               d.name  AS division,
               NULLIF(sp.name, 'Sin especialidad') AS especialidad,
               sh.name::turno AS turno,
               co.is_active, co.created_at
        FROM courses co
        JOIN academic_years ay ON ay.id = co.academic_year_id
        JOIN divisions      d  ON d.id  = co.division_id
        JOIN specialties    sp ON sp.id = co.specialty_id
        JOIN shifts         sh ON sh.id = co.shift_id;

        INSERT INTO cursos (anio, division, grupo_taller, especialidad, turno, activo, creado_en)
        SELECT cr.anio, cr.division, COALESCE(wg.name, ''), cr.especialidad,
               cr.turno, cr.is_active, cr.created_at
        FROM _course_rev cr
        LEFT JOIN course_workshop_groups cwg ON cwg.course_id = cr.course_uuid
        LEFT JOIN workshop_groups wg ON wg.id = cwg.workshop_group_id
        ON CONFLICT (anio, division, grupo_taller, turno) DO NOTHING;

        -- course_uuid -> chosen legacy curso id (grupo_taller='' preferred, else lowest)
        CREATE TEMP TABLE _course_id_map ON COMMIT DROP AS
        SELECT cr.course_uuid,
               (SELECT c.id FROM cursos c
                 WHERE c.anio = cr.anio AND c.division = cr.division AND c.turno = cr.turno
                 ORDER BY (c.grupo_taller <> '') , c.id
                 LIMIT 1) AS curso_id
        FROM _course_rev cr;

        -- usuarios (insert directly from users; no snapshot temp table, so the
        -- user_role enum has no lingering dependency at DROP TYPE time)
        INSERT INTO usuarios (correo, password_hash, rol, nombre, apellido, activo, creado_en, actualizado_en)
        SELECT u.username, u.password_hash,
               (CASE u.role::text WHEN 'direction' THEN 'direccion'
                                  WHEN 'preceptor' THEN 'preceptor' END)::rol_usuario,
               split_part(u.full_name, ', ', 2),
               split_part(u.full_name, ', ', 1),
               u.is_active, u.created_at, u.updated_at
        FROM users u;

        CREATE TEMP TABLE _user_id_map ON COMMIT DROP AS
        SELECT u.id AS user_uuid, le.id AS usuario_id
        FROM users u JOIN usuarios le ON le.correo = u.username;

        -- alumnos (from students + current enrollment)
        CREATE TEMP TABLE _student_id_map (student_uuid VARCHAR(36), alumno_id INT) ON COMMIT DROP;

        WITH cur AS (
            SELECT DISTINCT ON (e.student_id) e.student_id, e.course_id
            FROM student_course_enrollments e
            ORDER BY e.student_id, (e.end_date IS NULL) DESC, e.start_date DESC
        ), ins AS (
            INSERT INTO alumnos (nombre, apellido, dni, curso_id, nfc_uid, qr_token, activo, creado_en, actualizado_en)
            SELECT s.first_name, s.last_name, s.national_id, cim.curso_id,
                   s.nfc_uid, s.qr_code, s.is_active, s.created_at, s.updated_at
            FROM students s
            JOIN cur ON cur.student_id = s.id
            JOIN _course_id_map cim ON cim.course_uuid = cur.course_id
            RETURNING id, dni
        )
        INSERT INTO _student_id_map (student_uuid, alumno_id)
        SELECT s.id, ins.id FROM ins JOIN students s ON s.national_id = ins.dni;

        -- registros_ingreso (best-effort; new ULIDs since originals were lost)
        INSERT INTO registros_ingreso
            (ulid, alumno_id, metodo, registrado_en, sincronizado_en, creado_por, estado,
             es_falta_no_computable, motivo_no_computable, no_computable_automatico)
        SELECT substr(replace(ar.id, '-', ''), 1, 26),
               sim.alumno_id,
               ar.source::text::metodo_registro,
               ar.check_in_time,
               ar.synced_at,
               uim.usuario_id,
               (CASE ar.status::text
                    WHEN 'present'              THEN 'presente'
                    WHEN 'late'                 THEN 'tarde'
                    WHEN 'absent'               THEN 'ausente'
                    WHEN 'absent_with_presence' THEN 'ausente_con_permanencia'
                    WHEN 'non_computable'       THEN 'falta_no_computable' END)::estado_asistencia,
               (nca.id IS NOT NULL),
               nca.detail,
               COALESCE(nca.reason_type::text = 'schedule_overlap', FALSE)
        FROM attendance_records ar
        JOIN _student_id_map sim ON sim.student_uuid = ar.student_id
        LEFT JOIN _user_id_map uim ON uim.user_uuid = ar.registered_by
        LEFT JOIN non_computable_absences nca ON nca.attendance_record_id = ar.id
        ON CONFLICT (ulid) DO NOTHING;
    END
    $rev$;
    """)

    # 4. Drop the new-schema tables and enum types
    op.execute("""
        DROP TABLE IF EXISTS non_computable_absences;
        DROP TABLE IF EXISTS early_departures;
        DROP TABLE IF EXISTS attendance_records;
        DROP TABLE IF EXISTS schedule_exceptions;
        DROP TABLE IF EXISTS schedule_slots;
        DROP TABLE IF EXISTS repeating_subjects;
        DROP TABLE IF EXISTS student_workshop_groups;
        DROP TABLE IF EXISTS student_course_enrollments;
        DROP TABLE IF EXISTS students;
        DROP TABLE IF EXISTS preceptor_course_assignments;
        DROP TABLE IF EXISTS devices;
        DROP TABLE IF EXISTS course_workshop_groups;
        DROP TABLE IF EXISTS courses;
        DROP TABLE IF EXISTS workshop_groups;
        DROP TABLE IF EXISTS shifts;
        DROP TABLE IF EXISTS specialties;
        DROP TABLE IF EXISTS divisions;
        DROP TABLE IF EXISTS academic_years;
        DROP TABLE IF EXISTS users;

        DROP TYPE IF EXISTS non_computable_reason;
        DROP TYPE IF EXISTS attendance_source;
        DROP TYPE IF EXISTS attendance_status;
        DROP TYPE IF EXISTS exception_scope;
        DROP TYPE IF EXISTS activity_type;
        DROP TYPE IF EXISTS enrollment_type;
        DROP TYPE IF EXISTS user_role;
    """)
