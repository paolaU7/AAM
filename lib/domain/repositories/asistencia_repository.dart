import '../entities/registro_asistencia.dart';
import '../entities/curso.dart';

abstract class AsistenciaRepository {
  Future<List<RegistroAsistencia>> getRegistrosPorCursoYFecha(
    String cursoId,
    DateTime fecha,
  );

  Future<ResumenAsistencia> getResumenDiario(DateTime fecha);

  Future<ResumenAsistencia> getResumenPorTurno(
    String turno,
    DateTime fecha,
  );

  Future<RegistroAsistencia> registrarIngresoManual({
    required String alumnoId,
    required String cursoId,
    required DateTime horaIngreso,
  });

  Future<RegistroAsistencia> registrarRetiro({
    required String registroId,
    required DateTime horaRetiro,
    required String motivo,
  });

  Future<RegistroAsistencia> marcarNoComputable({
    required String registroId,
    required String motivo,
  });
}
