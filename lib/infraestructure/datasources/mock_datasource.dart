import '../../domain/entities/alumno.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/registro_asistencia.dart';
import '../../domain/entities/usuario.dart';

/// Fuente de datos mock — reemplazar por ApiDatasource cuando el backend esté listo.
/// Listas vacías: los datos reales vendrán del backend.
class MockDatasource {
  // ── Alumnos ────────────────────────────────────────────────────────────────
  List<Alumno> getAlumnos() => [];

  // ── Cursos ─────────────────────────────────────────────────────────────────
  List<Curso> getCursos() => [];

  // ── Registros de asistencia ────────────────────────────────────────────────
  List<RegistroAsistencia> getRegistros(String cursoId, DateTime fecha) => [];

  // ── Resumen de asistencia ──────────────────────────────────────────────────
  ResumenAsistencia getResumenGlobal(DateTime fecha) => ResumenAsistencia(
    fecha: fecha,
    presentes: 0,
    ausentes: 0,
    tardanzas: 0,
    noComputables: 0,
    retiros: 0,
    total: 0,
  );

  ResumenAsistencia getResumenTurno(String turno, DateTime fecha) => ResumenAsistencia(
    fecha: fecha,
    presentes: 0,
    ausentes: 0,
    tardanzas: 0,
    noComputables: 0,
    retiros: 0,
    total: 0,
  );

  // ── Usuarios ───────────────────────────────────────────────────────────────
  List<Usuario> getUsuarios() => [];
}

extension _DateTimeCopy on DateTime {
  DateTime copyWith({int? hour, int? minute}) =>
      DateTime(year, month, day, hour ?? this.hour, minute ?? this.minute);
}