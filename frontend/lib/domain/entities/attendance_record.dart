/// Domain entity: AttendanceRecord
/// Represents a student's check-in/check-out for a given day.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.date,
    required this.checkInTime,
    required this.source,
    required this.status,
    this.departureTime,
    this.departureReason,
    this.isNonComputable = false,
    this.nonComputableReason,
  });

  final String id;             // ULID generated on ESP32 or backend
  final String studentId;
  final String studentName;
  final String courseId;
  final DateTime date;
  final DateTime? checkInTime;
  final AttendanceSource source;
  final AttendanceStatus status;
  final DateTime? departureTime;
  final String? departureReason;
  final bool isNonComputable;
  final String? nonComputableReason;

  bool get hasEarlyDeparture => departureTime != null;

  AttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? courseId,
    DateTime? date,
    DateTime? checkInTime,
    AttendanceSource? source,
    AttendanceStatus? status,
    DateTime? departureTime,
    String? departureReason,
    bool? isNonComputable,
    String? nonComputableReason,
  }) {
    return AttendanceRecord(
      id:                  id                  ?? this.id,
      studentId:           studentId           ?? this.studentId,
      studentName:         studentName         ?? this.studentName,
      courseId:            courseId            ?? this.courseId,
      date:                date                ?? this.date,
      checkInTime:         checkInTime         ?? this.checkInTime,
      source:              source              ?? this.source,
      status:              status              ?? this.status,
      departureTime:       departureTime       ?? this.departureTime,
      departureReason:     departureReason     ?? this.departureReason,
      isNonComputable:     isNonComputable     ?? this.isNonComputable,
      nonComputableReason: nonComputableReason ?? this.nonComputableReason,
    );
  }
}

enum AttendanceSource { nfc, qr, manual, unknown }

enum AttendanceStatus { present, absent, late, nonComputable }

extension AttendanceStatusLabel on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:       return 'Presente';
      case AttendanceStatus.absent:        return 'Ausente';
      case AttendanceStatus.late:          return 'Tardanza';
      case AttendanceStatus.nonComputable: return 'No computable';
    }
  }
}

extension AttendanceSourceLabel on AttendanceSource {
  String get label {
    switch (this) {
      case AttendanceSource.nfc:     return 'NFC';
      case AttendanceSource.qr:      return 'QR';
      case AttendanceSource.manual:  return 'Manual';
      case AttendanceSource.unknown: return '—';
    }
  }
}

/// Aggregated attendance summary (for dashboard and stats)
class AttendanceSummary {
  const AttendanceSummary({
    required this.date,
    required this.present,
    required this.absent,
    required this.late,
    required this.nonComputable,
    required this.earlyDepartures,
    required this.total,
  });

  final DateTime date;
  final int present;
  final int absent;
  final int late;
  final int nonComputable;
  final int earlyDepartures;
  final int total;

  double get attendancePercentage =>
      total > 0 ? (present / total) * 100 : 0;
}