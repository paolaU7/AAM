import '../entities/registro_asistencia.dart';
import '../repositories/asistencia_repository.dart';

class GetAsistenciaDiaria {
  const GetAsistenciaDiaria(this.repository);
  final AsistenciaRepository repository;

  Future<List<RegistroAsistencia>> call({
    required String cursoId,
    required DateTime fecha,
  }) {
    return repository.getRegistrosPorCursoYFecha(cursoId, fecha);
  }
}

class RegistrarIngresoManual {
  const RegistrarIngresoManual(this.repository);
  final AsistenciaRepository repository;

  Future<RegistroAsistencia> call({
    required String alumnoId,
    required String cursoId,
    required DateTime horaIngreso,
  }) {
    return repository.registrarIngresoManual(
      alumnoId:    alumnoId,
      cursoId:     cursoId,
      horaIngreso: horaIngreso,
    );
  }
}

class RegistrarRetiro {
  const RegistrarRetiro(this.repository);
  final AsistenciaRepository repository;

  Future<RegistroAsistencia> call({
    required String registroId,
    required DateTime horaRetiro,
    required String motivo,
  }) {
    return repository.registrarRetiro(
      registroId:  registroId,
      horaRetiro:  horaRetiro,
      motivo:      motivo,
    );
  }
}
