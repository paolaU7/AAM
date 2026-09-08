package postgres

import (
	"context"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/paolaU7/AAM/backend/internal/domain"
)

type NotificationRepo struct{ pool *pgxpool.Pool }

func NewNotificationRepo(pool *pgxpool.Pool) *NotificationRepo { return &NotificationRepo{pool} }

// GetAlerts combines the 3 alert categories into one list, computed against
// current data — nothing here is persisted. Ported from
// notification_repository_impl.py.
func (r *NotificationRepo) GetAlerts(ctx context.Context, preceptorTempAlertDays, scheduleExceptionAlertDays, consecutiveAbsencesThreshold int) ([]domain.Notification, error) {
	var alerts []domain.Notification

	a1, err := r.preceptorTempEndingSoon(ctx, preceptorTempAlertDays)
	if err != nil {
		return nil, err
	}
	alerts = append(alerts, a1...)

	a2, err := r.scheduleExceptionsUpcoming(ctx, scheduleExceptionAlertDays)
	if err != nil {
		return nil, err
	}
	alerts = append(alerts, a2...)

	a3, err := r.consecutiveAbsences(ctx, consecutiveAbsencesThreshold)
	if err != nil {
		return nil, err
	}
	alerts = append(alerts, a3...)

	return alerts, nil
}

func (r *NotificationRepo) preceptorTempEndingSoon(ctx context.Context, alertDays int) ([]domain.Notification, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT u.full_name, c.academic_year, c.grade_year, c.division,
		       (t.end_date - CURRENT_DATE) AS days_left
		FROM course_preceptor_temp_assignments t
		JOIN courses c ON c.id = t.course_id
		JOIN users u ON u.id = t.preceptor_id
		WHERE t.end_date >= CURRENT_DATE`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.Notification
	for rows.Next() {
		var name string
		var ay, gy, dv, daysLeft int
		if err := rows.Scan(&name, &ay, &gy, &dv, &daysLeft); err != nil {
			return nil, err
		}
		if daysLeft > alertDays {
			continue
		}
		var cuando string
		switch {
		case daysLeft == 0:
			cuando = "termina hoy"
		case daysLeft == 1:
			cuando = "termina mañana"
		default:
			cuando = fmt.Sprintf("termina en %d días", daysLeft)
		}
		out = append(out, domain.Notification{
			Type:    domain.NotifPreceptorTempAssignment,
			Message: fmt.Sprintf("El reemplazo de %s en %s %s", name, domain.CourseLabel(ay, gy, dv), cuando),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Message < out[j].Message })
	return out, nil
}

func (r *NotificationRepo) scheduleExceptionsUpcoming(ctx context.Context, alertDays int) ([]domain.Notification, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT to_char(se.exception_date, 'DD/MM') AS fecha,
		       se.reason,
		       c.academic_year, c.grade_year, c.division,
		       (se.exception_date - CURRENT_DATE) AS days_left
		FROM schedule_exceptions se
		JOIN courses c ON c.id = se.course_id
		WHERE se.exception_date >= CURRENT_DATE
		ORDER BY se.exception_date`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []domain.Notification
	for rows.Next() {
		var fecha string
		var reason *string
		var ay, gy, dv, daysLeft int
		if err := rows.Scan(&fecha, &reason, &ay, &gy, &dv, &daysLeft); err != nil {
			return nil, err
		}
		if daysLeft > alertDays {
			continue
		}
		motivo := ""
		if reason != nil && *reason != "" {
			motivo = ": " + *reason
		}
		out = append(out, domain.Notification{
			Type:    domain.NotifScheduleException,
			Message: fmt.Sprintf("%s tiene una excepción de horario el %s%s", domain.CourseLabel(ay, gy, dv), fecha, motivo),
		})
	}
	return out, rows.Err()
}

func (r *NotificationRepo) consecutiveAbsences(ctx context.Context, threshold int) ([]domain.Notification, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT ar.student_id, ar.status::text, s.last_name, s.first_name
		FROM attendance_records ar
		JOIN students s ON s.id = ar.student_id
		WHERE s.is_active
		ORDER BY ar.student_id, ar.entry_timestamp DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type rec struct{ studentID, status, last, first string }
	var all []rec
	for rows.Next() {
		var x rec
		if err := rows.Scan(&x.studentID, &x.status, &x.last, &x.first); err != nil {
			return nil, err
		}
		all = append(all, x)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	var out []domain.Notification
	for i := 0; i < len(all); {
		// group is all[i..j) — same student, ordered most-recent first.
		j := i
		for j < len(all) && all[j].studentID == all[i].studentID {
			j++
		}
		streak := 0
		name := all[i].last + ", " + all[i].first
	group:
		for _, x := range all[i:j] {
			switch x.status {
			case domain.StatusAbsent:
				streak++
			case domain.StatusNonComputableAbsence:
				// Designed to affect no statistic — skip without breaking
				// or adding to the streak.
			default:
				// present / late / absent_with_presence: the student showed
				// up that day, the streak ends.
				break group
			}
		}
		if streak >= threshold {
			out = append(out, domain.Notification{
				Type:    domain.NotifConsecutiveAbsences,
				Message: fmt.Sprintf("%s lleva %d faltas consecutivas", name, streak),
			})
		}
		i = j
	}
	sort.Slice(out, func(a, b int) bool { return out[a].Message < out[b].Message })
	return out, nil
}
