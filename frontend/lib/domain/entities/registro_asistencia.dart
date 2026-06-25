/// Entidad de dominio: RegistroAsistencia
/// Representa un check-in/check-out de un alumno en un día dado.
class RegistroAsistencia {
  const RegistroAsistencia({
    required this.id,
    required this.alumnoId,
    required this.alumnoNombre,
    required this.cursoId,
    required this.fecha,
    required this.horaIngreso,
    required this.metodoIngreso,
    required this.estado,
    this.horaRetiro,
    this.motivoRetiro,
    this.esNoComputable = false,
    this.motivoNoComputable,
  });

  final String id;             // ULID generado en ESP32 o backend
  final String alumnoId;
  final String alumnoNombre;
  final String cursoId;
  final DateTime fecha;
  final DateTime? horaIngreso;
  final MetodoIngreso metodoIngreso;
  final EstadoAsistencia estado;
  final DateTime? horaRetiro;
  final String? motivoRetiro;
  final bool esNoComputable;
  final String? motivoNoComputable;

  bool get tieneRetiroAnticipado => horaRetiro != null;

  RegistroAsistencia copyWith({
    String? id,
    String? alumnoId,
    String? alumnoNombre,
    String? cursoId,
    DateTime? fecha,
    DateTime? horaIngreso,
    MetodoIngreso? metodoIngreso,
    EstadoAsistencia? estado,
    DateTime? horaRetiro,
    String? motivoRetiro,
    bool? esNoComputable,
    String? motivoNoComputable,
  }) {
    return RegistroAsistencia(
      id:                 id                 ?? this.id,
      alumnoId:           alumnoId           ?? this.alumnoId,
      alumnoNombre:       alumnoNombre       ?? this.alumnoNombre,
      cursoId:            cursoId            ?? this.cursoId,
      fecha:              fecha              ?? this.fecha,
      horaIngreso:        horaIngreso        ?? this.horaIngreso,
      metodoIngreso:      metodoIngreso      ?? this.metodoIngreso,
      estado:             estado             ?? this.estado,
      horaRetiro:         horaRetiro         ?? this.horaRetiro,
      motivoRetiro:       motivoRetiro       ?? this.motivoRetiro,
      esNoComputable:     esNoComputable     ?? this.esNoComputable,
      motivoNoComputable: motivoNoComputable ?? this.motivoNoComputable,
    );
  }
}

enum MetodoIngreso { nfc, qr, manual, desconocido }

enum EstadoAsistencia { presente, ausente, tardanza, noComputable }

extension EstadoAsistenciaLabel on EstadoAsistencia {
  String get label {
    switch (this) {
      case EstadoAsistencia.presente:     return 'Presente';
      case EstadoAsistencia.ausente:      return 'Ausente';
      case EstadoAsistencia.tardanza:     return 'Tardanza';
      case EstadoAsistencia.noComputable: return 'No computable';
    }
  }
}

extension MetodoIngresoLabel on MetodoIngreso {
  String get label {
    switch (this) {
      case MetodoIngreso.nfc:         return 'NFC';
      case MetodoIngreso.qr:          return 'QR';
      case MetodoIngreso.manual:      return 'Manual';
      case MetodoIngreso.desconocido: return '—';
    }
  }
}
