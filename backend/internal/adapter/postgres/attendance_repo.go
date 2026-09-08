package postgres

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/oklog/ulid/v2"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type AttendanceRepo struct{ pool *pgxpool.Pool }

func NewAttendanceRepo(pool *pgxpool.Pool) *AttendanceRepo { return &AttendanceRepo{pool} }

const registroSelect = `
	SELECT ar.id, ar.student_id,
	       COALESCE(s.last_name || ', ' || s.first_name, ''),
	       ar.course_id, ar.entry_timestamp, ar.source::text, ar.status::text,
	       ed.departure_time, ed.reason
	FROM attendance_records ar
	LEFT JOIN students s ON s.id = ar.student_id
	LEFT JOIN LATERAL (
	    SELECT departure_time, reason FROM early_departures e
	    WHERE e.attendance_record_id = ar.id
	    ORDER BY e.created_at LIMIT 1
	) ed ON true`

func scanRegistro(row pgx.Row) (domain.RegistroAsistencia, error) {
	var r domain.RegistroAsistencia
	var depTime *time.Time
	var depReason *string
	if err := row.Scan(
		&r.ID, &r.StudentID, &r.StudentName, &r.CourseID, &r.EntryTimestamp,
		&r.Source, &r.Status, &depTime, &depReason,
	); err != nil {
		return domain.RegistroAsistencia{}, err
	}
	r.DepartureTime = depTime
	r.DepartureReason = depReason
	return r, nil
}

func (r *AttendanceRepo) loadOne(ctx context.Context, id string) (*domain.RegistroAsistencia, error) {
	reg, err := scanRegistro(r.pool.QueryRow(ctx, registroSelect+" WHERE ar.id = $1", id))
	if noRows(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &reg, nil
}

func (r *AttendanceRepo) GetByCourseAndDate(ctx context.Context, courseID, date string) ([]domain.RegistroAsistencia, error) {
	rows, err := r.pool.Query(ctx,
		registroSelect+" WHERE ar.course_id = $1 AND ar.entry_timestamp::date = $2::date ORDER BY ar.entry_timestamp",
		courseID, date)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.RegistroAsistencia
	for rows.Next() {
		reg, err := scanRegistro(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, reg)
	}
	return out, rows.Err()
}

const summaryAgg = `
	count(*) FILTER (WHERE ar.status = 'present'),
	count(*) FILTER (WHERE ar.status IN ('absent', 'absent_with_presence')),
	count(*) FILTER (WHERE ar.status = 'late'),
	count(*) FILTER (WHERE ar.status = 'non_computable_absence'),
	count(DISTINCT ed.attendance_record_id),
	count(*)`

func (r *AttendanceRepo) scanSummary(row pgx.Row, date string) (domain.ResumenAsistencia, error) {
	s := domain.ResumenAsistencia{Date: date}
	err := row.Scan(&s.Present, &s.Absent, &s.Late, &s.NonComputableAbsence, &s.EarlyDepartures, &s.Total)
	return s, err
}

func (r *AttendanceRepo) GetDailySummary(ctx context.Context, date string) (domain.ResumenAsistencia, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT `+summaryAgg+`
		FROM attendance_records ar
		LEFT JOIN early_departures ed ON ed.attendance_record_id = ar.id
		WHERE ar.entry_timestamp::date = $1::date`, date)
	return r.scanSummary(row, date)
}

func (r *AttendanceRepo) GetSummaryByShift(ctx context.Context, shift, date string) (domain.ResumenAsistencia, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT `+summaryAgg+`
		FROM attendance_records ar
		JOIN time_slots ts ON ts.id = ar.time_slot_id
		LEFT JOIN early_departures ed ON ed.attendance_record_id = ar.id
		WHERE ts.shift::text = $1 AND ar.entry_timestamp::date = $2::date`, shift, date)
	return r.scanSummary(row, date)
}

func (r *AttendanceRepo) RegisterManualCheckIn(ctx context.Context, studentID, courseID string, entryTimestamp time.Time, status string) (domain.RegistroAsistencia, error) {
	id := ulid.Make().String()
	_, err := r.pool.Exec(ctx, `
		INSERT INTO attendance_records (id, student_id, course_id, source, status, entry_timestamp)
		VALUES ($1, $2, $3, 'manual'::attendance_source, $4::attendance_status, $5)`,
		id, studentID, courseID, status, entryTimestamp)
	if err != nil {
		return domain.RegistroAsistencia{}, mapDBError(err, "No se pudo registrar el ingreso manual.")
	}
	reg, err := r.loadOne(ctx, id)
	if err != nil || reg == nil {
		return domain.RegistroAsistencia{}, err
	}
	return *reg, nil
}

func (r *AttendanceRepo) RegisterEarlyDeparture(ctx context.Context, recordID string, departureTime time.Time, reason, registeredBy string) (*domain.RegistroAsistencia, error) {
	var exists bool
	if err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM attendance_records WHERE id = $1)`, recordID).Scan(&exists); err != nil {
		return nil, err
	}
	if !exists {
		return nil, nil
	}
	_, err := r.pool.Exec(ctx, `
		INSERT INTO early_departures (attendance_record_id, departure_time, reason, registered_by)
		VALUES ($1, $2, $3, $4)`,
		recordID, departureTime, reason, registeredBy)
	if err != nil {
		return nil, mapDBError(err, "No se pudo registrar el retiro anticipado.")
	}
	return r.loadOne(ctx, recordID)
}

func (r *AttendanceRepo) MarkNonComputable(ctx context.Context, recordID string) (*domain.RegistroAsistencia, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE attendance_records SET status = 'non_computable_absence'::attendance_status WHERE id = $1`, recordID)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, nil
	}
	return r.loadOne(ctx, recordID)
}
