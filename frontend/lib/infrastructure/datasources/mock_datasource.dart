import '../../domain/entities/student.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/user.dart';

/// Fuente de datos mock — reemplazar por ApiDatasource cuando el backend esté listo.
/// Listas vacías: los datos reales vendrán del backend.
class MockDatasource {
  // ── Alumnos ────────────────────────────────────────────────────────────────
  List<Student> getAlumnos() => [];

  // ── Cursos ─────────────────────────────────────────────────────────────────
  List<Course> getCursos() => [
    const Course(id: 'c1', academicYear: '4', division: 'A', specialty: 'Informática', shift: 'Mañana',     totalStudents: 0, workshopGroups: ['Robótica']),
    const Course(id: 'c2', academicYear: '4', division: 'B', specialty: 'Electrónica', shift: 'Mañana',     totalStudents: 0),
    const Course(id: 'c3', academicYear: '5', division: 'A', specialty: 'Mecánica',    shift: 'Tarde',      totalStudents: 0),
    const Course(id: 'c4', academicYear: '1', division: 'C', specialty: 'Informática', shift: 'Vespertino', totalStudents: 0),
  ];

  // ── Registros de asistencia ────────────────────────────────────────────────
  List<AttendanceRecord> getRegistros(String cursoId, DateTime fecha) => [];

  // ── Resumen de asistencia ──────────────────────────────────────────────────
  AttendanceSummary getResumenGlobal(DateTime fecha) => AttendanceSummary(
    date: fecha,
    present: 0,
    absent: 0,
    late: 0,
    nonComputable: 0,
    earlyDepartures: 0,
    total: 0,
  );

  AttendanceSummary getResumenTurno(String turno, DateTime fecha) => AttendanceSummary(
    date: fecha,
    present: 0,
    absent: 0,
    late: 0,
    nonComputable: 0,
    earlyDepartures: 0,
    total: 0,
  );

  // ── Usuarios ───────────────────────────────────────────────────────────────
  List<User> getUsuarios() => [];
}

