/// Domain entity: AttendanceRecord
/// Represents a student's check-in/check-out for a given day.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.entryTimestamp,
    required this.source,
    required this.status,
    this.departureTime,
    this.departureReason,
  });

  final String id;             // ULID generado en el ESP32 o en el backend (alta manual)
  final String studentId;
  final String studentName;
  final String courseId;
  final DateTime entryTimestamp;
  final AttendanceSource source;
  final AttendanceStatus status;
  final DateTime? departureTime;
  final String? departureReason;

  bool get hasEarlyDeparture => departureTime != null;

  AttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? courseId,
    DateTime? entryTimestamp,
    AttendanceSource? source,
    AttendanceStatus? status,
    DateTime? departureTime,
    String? departureReason,
  }) {
    return AttendanceRecord(
      id:               id               ?? this.id,
      studentId:        studentId        ?? this.studentId,
      studentName:      studentName      ?? this.studentName,
      courseId:         courseId         ?? this.courseId,
      entryTimestamp:   entryTimestamp   ?? this.entryTimestamp,
      source:           source           ?? this.source,
      status:           status           ?? this.status,
      departureTime:    departureTime    ?? this.departureTime,
      departureReason:  departureReason  ?? this.departureReason,
    );
  }
}

enum AttendanceSource { nfc, qr, manual }

enum AttendanceStatus { present, late, absent, absentWithPresence, nonComputableAbsence }

extension AttendanceStatusLabel on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:               return 'Presente';
      case AttendanceStatus.absent:                return 'Ausente';
      case AttendanceStatus.late:                  return 'Tardanza';
      case AttendanceStatus.absentWithPresence:    return 'Ausente con permanencia';
      case AttendanceStatus.nonComputableAbsence:  return 'No computable';
    }
  }
}

extension AttendanceSourceLabel on AttendanceSource {
  String get label {
    switch (this) {
      case AttendanceSource.nfc:     return 'NFC';
      case AttendanceSource.qr:      return 'QR';
      case AttendanceSource.manual:  return 'Manual';
    }
  }
}

/// Aggregated attendance summary (for dashboard and stats).
/// `absent` incluye `absent_with_presence` — así lo define DATABASE_SCHEMA.md
/// (cuenta como ausente a efectos del RITE).
class AttendanceSummary {
  const AttendanceSummary({
    required this.date,
    required this.present,
    required this.absent,
    required this.late,
    required this.nonComputableAbsence,
    required this.earlyDepartures,
    required this.total,
  });

  final DateTime date;
  final int present;
  final int absent;
  final int late;
  final int nonComputableAbsence;
  final int earlyDepartures;
  final int total;

  double get attendancePercentage =>
      total > 0 ? (present / total) * 100 : 0;
}
