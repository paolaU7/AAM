import '../entities/curso.dart';
import '../repositories/asistencia_repository.dart';
import '../repositories/curso_repository.dart';

/// Caso de uso: obtener todos los datos que necesita el Dashboard
class GetResumenDashboard {
  const GetResumenDashboard({
    required this.asistenciaRepository,
    required this.cursoRepository,
  });

  final AsistenciaRepository asistenciaRepository;
  final CursoRepository cursoRepository;

  Future<ResumenDashboard> call(DateTime fecha) async {
    final resumenGlobal = await asistenciaRepository.getResumenDiario(fecha);
    final resumenManiana = await asistenciaRepository.getResumenPorTurno('mañana',     fecha);
    final resumenTarde   = await asistenciaRepository.getResumenPorTurno('tarde',      fecha);
    final resumenVesp    = await asistenciaRepository.getResumenPorTurno('vespertino', fecha);
    final cursos         = await cursoRepository.getCursos();

    return ResumenDashboard(
      resumenGlobal:    resumenGlobal,
      resumenManiana:   resumenManiana,
      resumenTarde:     resumenTarde,
      resumenVespertino: resumenVesp,
      cursos:           cursos,
    );
  }
}

class ResumenDashboard {
  const ResumenDashboard({
    required this.resumenGlobal,
    required this.resumenManiana,
    required this.resumenTarde,
    required this.resumenVespertino,
    required this.cursos,
  });

  final ResumenAsistencia resumenGlobal;
  final ResumenAsistencia resumenManiana;
  final ResumenAsistencia resumenTarde;
  final ResumenAsistencia resumenVespertino;
  final List<Curso> cursos;
}
