import '../../domain/entities/curso.dart';
import '../../domain/entities/registro_asistencia.dart';
import '../../domain/repositories/asistencia_repository.dart';
import '../datasources/mock_datasource.dart';
import '../datasources/api_datasource.dart';

class AsistenciaRepositoryImpl implements AsistenciaRepository {
  AsistenciaRepositoryImpl(this._datasource);
  final ApiDatasource _datasource;
  final MockDatasource _mock = MockDatasource();

  @override
  Future<List<RegistroAsistencia>> getRegistrosPorCursoYFecha(
    String cursoId,
    DateTime fecha,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mock.getRegistros(cursoId, fecha);
  }

  @override
  Future<ResumenAsistencia> getResumenDiario(DateTime fecha) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mock.getResumenGlobal(fecha);
  }

  @override
  Future<ResumenAsistencia> getResumenPorTurno(
    String turno,
    DateTime fecha,
  ) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _mock.getResumenTurno(turno, fecha);
  }

  @override
  Future<RegistroAsistencia> registrarIngresoManual({
    required String alumnoId,
    required String cursoId,
    required DateTime horaIngreso,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return RegistroAsistencia(
      id:            'mock_${DateTime.now().millisecondsSinceEpoch}',
      alumnoId:      alumnoId,
      alumnoNombre:  'Alumno Manual',
      cursoId:       cursoId,
      fecha:         DateTime(horaIngreso.year, horaIngreso.month, horaIngreso.day),
      horaIngreso:   horaIngreso,
      metodoIngreso: MetodoIngreso.manual,
      estado:        EstadoAsistencia.presente,
    );
  }

  @override
  Future<RegistroAsistencia> registrarRetiro({
    required String registroId,
    required DateTime horaRetiro,
    required String motivo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // En mock: devuelve un registro placeholder actualizado
    return RegistroAsistencia(
      id:            registroId,
      alumnoId:      '',
      alumnoNombre:  '',
      cursoId:       '',
      fecha:         DateTime.now(),
      horaIngreso:   null,
      metodoIngreso: MetodoIngreso.desconocido,
      estado:        EstadoAsistencia.presente,
      horaRetiro:    horaRetiro,
      motivoRetiro:  motivo,
    );
  }

  @override
  Future<RegistroAsistencia> marcarNoComputable({
    required String registroId,
    required String motivo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return RegistroAsistencia(
      id:                 registroId,
      alumnoId:           '',
      alumnoNombre:       '',
      cursoId:            '',
      fecha:              DateTime.now(),
      horaIngreso:        null,
      metodoIngreso:      MetodoIngreso.desconocido,
      estado:             EstadoAsistencia.noComputable,
      esNoComputable:     true,
      motivoNoComputable: motivo,
    );
  }
}
