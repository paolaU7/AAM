-- +goose Up
-- Realistic starter dataset for E.E.S.T. N°2 (Mar del Plata). Idempotent:
-- every INSERT is ON CONFLICT DO NOTHING, so re-running is safe. Explicit,
-- readable ids (slugs) are used for the seed rows so the relationships are
-- legible; real rows created through the API keep getting gen_random_uuid().
--
-- Seed credentials (development only):
--   dirección : usuario "fer.mar"  contraseña "dir.123"
--   preceptor : usuario "tor.jul"  contraseña "pre.123"
--   preceptor : usuario "gom.roc"  contraseña "pre.123"
--   lector    : X-API-Key: AAM-DEV-KEY-001

-- ── especialidades + configuración ──────────────────────────────────────────
INSERT INTO specialties (id, name, is_basic_cycle) VALUES
    ('spec-basico',         'Ciclo Básico',   TRUE),
    ('spec-prog',           'Programación',   FALSE),
    ('spec-electronica',    'Electrónica',    FALSE),
    ('spec-construcciones', 'Construcciones', FALSE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO school_settings (id) VALUES (TRUE) ON CONFLICT (id) DO NOTHING;

-- ── usuarios ────────────────────────────────────────────────────────────────
INSERT INTO users (id, email, password_hash, full_name, role, is_active) VALUES
    ('user-dir',  'fer.mar@aam.edu.ar', '$2a$10$wGYdcAYIGGx.h.gI2FEJ4OhUPbpgulRXgGaMy./JPbNke9EbEl9uO', 'Fernández, Marcela', 'principal', TRUE),
    ('user-prc1', 'tor.jul@aam.edu.ar', '$2a$10$wbELj6fYVGvqnpnCtDfWrObbMK36cN.EEYZDq6A7oEv9UgIFUK9U2', 'Torres, Julián',     'preceptor', TRUE),
    ('user-prc2', 'gom.roc@aam.edu.ar', '$2a$10$wbELj6fYVGvqnpnCtDfWrObbMK36cN.EEYZDq6A7oEv9UgIFUK9U2', 'Gómez, Rocío',       'preceptor', TRUE)
ON CONFLICT (email) DO NOTHING;

-- ── dispositivo lector ──────────────────────────────────────────────────────
INSERT INTO devices (id, device_name, location, api_key_hash, is_active) VALUES
    ('device-a12', 'ESP32-AULA-12', 'Aula 12', '$2a$10$AthjWyiLGLYopMSnkjf4Q.bdpKbtYpeh8UOnPapMICFQbdAKCzRWy', TRUE)
ON CONFLICT (device_name) DO NOTHING;

-- ── cursos ──────────────────────────────────────────────────────────────────
INSERT INTO courses (id, academic_year, grade_year, division, specialty_id) VALUES
    ('course-1-1', 2026, 1, 1, 'spec-basico'),
    ('course-3-2', 2026, 3, 2, 'spec-basico'),
    ('course-7-2', 2026, 7, 2, 'spec-prog')
ON CONFLICT (academic_year, grade_year, division) DO NOTHING;

INSERT INTO workshop_groups (id, course_id, group_label) VALUES
    ('wg-7-2-a', 'course-7-2', 'Grupo A'),
    ('wg-7-2-b', 'course-7-2', 'Grupo B')
ON CONFLICT (course_id, group_label) DO NOTHING;

-- ── materias + aplicabilidad + profesores ───────────────────────────────────
INSERT INTO subjects (id, name, subject_type) VALUES
    ('subj-matematica',  'Matemática',                     'curricular'),
    ('subj-lengua',      'Lengua y Literatura',            'curricular'),
    ('subj-pdp',         'Prácticas Profesionalizantes',   'curricular'),
    ('subj-taller-prog', 'Taller de Programación',         'workshop')
ON CONFLICT (name) DO NOTHING;

INSERT INTO subject_applicability (id, subject_id, grade_year, specialty_id) VALUES
    ('sa-mat-1',   'subj-matematica',  1, 'spec-basico'),
    ('sa-mat-3',   'subj-matematica',  3, 'spec-basico'),
    ('sa-mat-7',   'subj-matematica',  7, 'spec-prog'),
    ('sa-len-1',   'subj-lengua',      1, 'spec-basico'),
    ('sa-len-3',   'subj-lengua',      3, 'spec-basico'),
    ('sa-pdp-7',   'subj-pdp',         7, 'spec-prog'),
    ('sa-tprog-7', 'subj-taller-prog', 7, 'spec-prog')
ON CONFLICT (id) DO NOTHING;

INSERT INTO teachers (id, full_name, email, phone) VALUES
    ('teacher-1', 'Sandra Ledesma', 'sledesma@eest2.edu.ar', '223-555-1010'),
    ('teacher-2', 'Marcos Peralta', 'mperalta@eest2.edu.ar', '223-555-2020')
ON CONFLICT (id) DO NOTHING;

INSERT INTO course_subject_teachers (course_id, subject_id, teacher_id) VALUES
    ('course-7-2', 'subj-matematica', 'teacher-1'),
    ('course-7-2', 'subj-pdp',        'teacher-2')
ON CONFLICT (course_id, subject_id) DO NOTHING;

-- ── horario: franjas de asistencia (time_slots) ─────────────────────────────
INSERT INTO time_slots (id, course_id, shift, activity_type, day_of_week, start_time, end_time, late_tolerance_minutes) VALUES
    ('ts-72-1', 'course-7-2', 'afternoon', 'main_shift', 1, '13:00', '18:00', 10),
    ('ts-72-2', 'course-7-2', 'afternoon', 'main_shift', 2, '13:00', '18:00', 10),
    ('ts-72-3', 'course-7-2', 'afternoon', 'main_shift', 3, '13:00', '18:00', 10),
    ('ts-72-4', 'course-7-2', 'afternoon', 'main_shift', 4, '13:00', '18:00', 10),
    ('ts-72-5', 'course-7-2', 'afternoon', 'main_shift', 5, '13:00', '18:00', 10),
    ('ts-11-1', 'course-1-1', 'morning',   'main_shift', 1, '07:45', '12:45', 10),
    ('ts-11-2', 'course-1-1', 'morning',   'main_shift', 2, '07:45', '12:45', 10),
    ('ts-11-3', 'course-1-1', 'morning',   'main_shift', 3, '07:45', '12:45', 10),
    ('ts-11-4', 'course-1-1', 'morning',   'main_shift', 4, '07:45', '12:45', 10),
    ('ts-11-5', 'course-1-1', 'morning',   'main_shift', 5, '07:45', '12:45', 10)
ON CONFLICT (id) DO NOTHING;

-- ── horario detallado (class_periods) — 7mo 2da, lunes ──────────────────────
INSERT INTO class_periods (id, course_id, day_of_week, shift, period_order, period_type, subject_id, teacher_id, start_time, end_time) VALUES
    ('cp-72-1', 'course-7-2', 1, 'afternoon', 1, 'class',  'subj-matematica', 'teacher-1', '13:00', '14:20'),
    ('cp-72-2', 'course-7-2', 1, 'afternoon', 2, 'recess', NULL,              NULL,        '14:20', '14:30'),
    ('cp-72-3', 'course-7-2', 1, 'afternoon', 3, 'class',  'subj-pdp',        'teacher-2', '14:30', '15:50')
ON CONFLICT (id) DO NOTHING;

-- ── preceptores ─────────────────────────────────────────────────────────────
INSERT INTO course_preceptors (course_id, shift, preceptor_id) VALUES
    ('course-7-2', 'afternoon', 'user-prc1'),
    ('course-1-1', 'morning',   'user-prc2'),
    ('course-3-2', 'morning',   'user-prc2')
ON CONFLICT (course_id, shift) DO NOTHING;

INSERT INTO course_preceptor_temp_assignments (id, course_id, shift, preceptor_id, start_date, end_date, reason, created_by) VALUES
    ('cpta-1', 'course-1-1', 'morning', 'user-prc1', '2026-09-05', '2026-09-09', 'Licencia médica de la preceptora titular', 'user-dir')
ON CONFLICT (id) DO NOTHING;

-- ── alumnos ─────────────────────────────────────────────────────────────────
INSERT INTO students (id, first_name, last_name, document_number, course_id, workshop_group_id, is_repeating_student) VALUES
    ('st-72-1', 'Lucía',    'Paz',       '44111111', 'course-7-2', NULL,       TRUE),
    ('st-72-2', 'Benjamín', 'Acosta',    '44222222', 'course-7-2', 'wg-7-2-a', FALSE),
    ('st-72-3', 'Valentina','Ríos',      '44333333', 'course-7-2', 'wg-7-2-b', FALSE),
    ('st-72-4', 'Mateo',    'Suárez',    '44444444', 'course-7-2', NULL,       FALSE),
    ('st-32-1', 'Sofía',    'Domínguez', '46111111', 'course-3-2', NULL,       FALSE),
    ('st-32-2', 'Tomás',    'Herrera',   '46222222', 'course-3-2', NULL,       FALSE),
    ('st-32-3', 'Julieta',  'Cabrera',   '46333333', 'course-3-2', NULL,       FALSE),
    ('st-11-1', 'Bruno',    'Molina',    '48111111', 'course-1-1', NULL,       FALSE),
    ('st-11-2', 'Camila',   'Vega',      '48222222', 'course-1-1', NULL,       FALSE),
    ('st-11-3', 'Lucas',    'Ferreyra',  '48333333', 'course-1-1', NULL,       FALSE)
ON CONFLICT (document_number) DO NOTHING;

-- ── pulseras NFC ────────────────────────────────────────────────────────────
INSERT INTO nfc_bracelets (id, tag_uid, student_id) VALUES
    ('br-1', '04A1B2C3', 'st-72-1'),
    ('br-2', '04D4E5F6', 'st-72-2'),
    ('br-3', '04A7B8C9', 'st-72-3'),
    ('br-4', '0410203D', 'st-11-1')
ON CONFLICT (tag_uid) DO NOTHING;

-- ── asistencia — 7mo 2da, 2026-09-01 (lunes) ────────────────────────────────
INSERT INTO attendance_records (id, student_id, course_id, time_slot_id, device_id, source, status, entry_timestamp) VALUES
    ('01M1DYVD30QBD3JS98WFC20DSH', 'st-72-1', 'course-7-2', 'ts-72-1', 'device-a12', 'nfc', 'present',                '2026-09-01 13:02:00-03'),
    ('01M1DYX7P0TFPDHD0Y4SQJCG0S', 'st-72-2', 'course-7-2', 'ts-72-1', 'device-a12', 'nfc', 'late',                   '2026-09-01 13:18:00-03'),
    ('01M1DYZ290EJAJAA0N82CTHE3S', 'st-72-3', 'course-7-2', 'ts-72-1', 'device-a12', 'nfc', 'present',                '2026-09-01 13:05:00-03'),
    ('01M1DZ0WW0TAQM7NGY8GJ223VP', 'st-72-4', 'course-7-2', 'ts-72-1', NULL,         'manual', 'absent',              '2026-09-01 13:00:00-03'),
    ('01M1DZ2QF0JKZK75YR5W1TNXVY', 'st-72-1', 'course-7-2', 'ts-72-1', NULL,         'manual', 'non_computable_absence','2026-08-25 13:00:00-03')
ON CONFLICT (id) DO NOTHING;

-- Racha de faltas consecutivas para Mateo Suárez (dispara la alerta del panel).
INSERT INTO attendance_records (id, student_id, course_id, time_slot_id, source, status, entry_timestamp) VALUES
    ('01M1DZ4J20RFKBJFY43SKTZ750', 'st-72-4', 'course-7-2', 'ts-72-3', 'manual', 'absent', '2026-08-27 13:00:00-03'),
    ('01M1DZ6CN0WX8636KNXMK07P3N', 'st-72-4', 'course-7-2', 'ts-72-4', 'manual', 'absent', '2026-08-28 13:00:00-03'),
    ('01M1DZ8780A33TJCKB40TF1R3Q', 'st-72-4', 'course-7-2', 'ts-72-5', 'manual', 'absent', '2026-08-31 13:00:00-03')
ON CONFLICT (id) DO NOTHING;

-- Retiro anticipado vinculado al ingreso de Valentina Ríos.
INSERT INTO early_departures (id, attendance_record_id, departure_time, reason, registered_by) VALUES
    ('ed-1', '01M1DYZ290EJAJAA0N82CTHE3S', '2026-09-01 16:30:00-03', 'Turno médico', 'user-prc1')
ON CONFLICT (id) DO NOTHING;

-- ── excepción de horario próxima (alerta del panel) ─────────────────────────
INSERT INTO schedule_exceptions (id, course_id, exception_date, reason, created_by) VALUES
    ('se-1', 'course-7-2', '2026-09-08', 'Jornada institucional — se adelanta la salida', 'user-dir')
ON CONFLICT (course_id, exception_date) DO NOTHING;

-- +goose Down
SELECT 1;
