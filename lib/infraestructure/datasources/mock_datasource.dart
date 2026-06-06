import '../../domain/entities/alumno.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/registro_asistencia.dart';
import '../../domain/entities/usuario.dart';

/// Fuente de datos mock — reemplazar por ApiDatasource cuando el backend esté listo.
/// Implementa los datos hardcodeados que antes vivían en los screens.
class MockDatasource {
  // ── Alumnos ────────────────────────────────────────────────────────────────

  List<Alumno> getAlumnos() => [
    const Alumno(id: '01HX001', nombre: 'Ana',       apellido: 'Ferreyra',   dni: '43120', cursoId: 'c002', curso: '4° 2°', especialidad: 'Informática',    turno: 'mañana',   recursante: false, porcentajeAsistencia: 91.0),
    const Alumno(id: '01HX002', nombre: 'Lucas',     apellido: 'González',   dni: '43215', cursoId: 'c005', curso: '5° 3°', especialidad: 'Construcciones', turno: 'mañana',   recursante: false, porcentajeAsistencia: 75.2),
    const Alumno(id: '01HX003', nombre: 'Diego',     apellido: 'Romero',     dni: '43418', cursoId: 'c001', curso: '3° 1°', especialidad: 'Electrónica',    turno: 'tarde',    recursante: true,  porcentajeAsistencia: 88.5),
    const Alumno(id: '01HX004', nombre: 'Valentina', apellido: 'Torres',     dni: '43611', cursoId: 'c003', curso: '3° 2°', especialidad: 'Electrónica',    turno: 'tarde',    recursante: false, porcentajeAsistencia: 62.3),
    const Alumno(id: '01HX005', nombre: 'Sofía',     apellido: 'Medina',     dni: '42987', cursoId: 'c006', curso: '6° 1°', especialidad: 'Informática',    turno: 'mañana',   recursante: false, porcentajeAsistencia: 95.1),
    const Alumno(id: '01HX006', nombre: 'Mateo',     apellido: 'Acosta',     dni: '43782', cursoId: 'c004', curso: '4° 3°', especialidad: 'Construcciones', turno: 'mañana',   recursante: true,  porcentajeAsistencia: 80.0),
    const Alumno(id: '01HX007', nombre: 'Luciana',   apellido: 'Ríos',       dni: '43399', cursoId: 'c007', curso: '5° 2°', especialidad: 'Informática',    turno: 'tarde',    recursante: false, porcentajeAsistencia: 70.4),
    const Alumno(id: '01HX008', nombre: 'Emanuel',   apellido: 'Gutiérrez',  dni: '43801', cursoId: 'c008', curso: '3° 3°', especialidad: 'Construcciones', turno: 'vespertino', recursante: false, porcentajeAsistencia: 55.8),
    const Alumno(id: '01HX009', nombre: 'Camila',    apellido: 'Vidal',      dni: '42770', cursoId: 'c009', curso: '6° 2°', especialidad: 'Electrónica',    turno: 'vespertino', recursante: false, porcentajeAsistencia: 98.2),
    const Alumno(id: '01HX010', nombre: 'Facundo',   apellido: 'Suárez',     dni: '43567', cursoId: 'c010', curso: '4° 1°', especialidad: 'Informática',    turno: 'tarde',    recursante: false, porcentajeAsistencia: 84.6),
  ];

  // ── Cursos ─────────────────────────────────────────────────────────────────

  List<Curso> getCursos() => [
    const Curso(id: 'c001', anio: 3, division: '1°', especialidad: 'Electrónica',    turno: 'tarde',      totalAlumnos: 26, horarioIngreso: '13:00', horarioEgreso: '17:20'),
    const Curso(id: 'c002', anio: 4, division: '2°', especialidad: 'Informática',    turno: 'mañana',     totalAlumnos: 30, horarioIngreso: '08:00', horarioEgreso: '12:20'),
    const Curso(id: 'c003', anio: 3, division: '2°', especialidad: 'Electrónica',    turno: 'tarde',      totalAlumnos: 24, horarioIngreso: '13:00', horarioEgreso: '17:20'),
    const Curso(id: 'c004', anio: 4, division: '3°', especialidad: 'Construcciones', turno: 'mañana',     totalAlumnos: 28, horarioIngreso: '08:00', horarioEgreso: '12:20'),
    const Curso(id: 'c005', anio: 5, division: '3°', especialidad: 'Construcciones', turno: 'mañana',     totalAlumnos: 26, horarioIngreso: '08:00', horarioEgreso: '12:20'),
    const Curso(id: 'c006', anio: 6, division: '1°', especialidad: 'Informática',    turno: 'mañana',     totalAlumnos: 20, horarioIngreso: '08:00', horarioEgreso: '12:20'),
    const Curso(id: 'c007', anio: 5, division: '2°', especialidad: 'Informática',    turno: 'tarde',      totalAlumnos: 22, horarioIngreso: '13:00', horarioEgreso: '17:20'),
    const Curso(id: 'c008', anio: 3, division: '3°', especialidad: 'Construcciones', turno: 'vespertino', totalAlumnos: 25, horarioIngreso: '17:30', horarioEgreso: '21:00'),
    const Curso(id: 'c009', anio: 6, division: '2°', especialidad: 'Electrónica',    turno: 'vespertino', totalAlumnos: 18, horarioIngreso: '17:30', horarioEgreso: '21:00'),
    const Curso(id: 'c010', anio: 4, division: '1°', especialidad: 'Informática',    turno: 'tarde',      totalAlumnos: 29, horarioIngreso: '13:00', horarioEgreso: '17:20'),
  ];

  // ── Registros de asistencia ────────────────────────────────────────────────

  List<RegistroAsistencia> getRegistros(String cursoId, DateTime fecha) {
    final hoy = DateTime(fecha.year, fecha.month, fecha.day);
    return [
      RegistroAsistencia(id: 'r001', alumnoId: '01HX001', alumnoNombre: 'Ferreyra, Ana P.',    cursoId: cursoId, fecha: hoy, horaIngreso: hoy.copyWith(hour: 7, minute: 52), metodoIngreso: MetodoIngreso.nfc,    estado: EstadoAsistencia.presente,  horaRetiro: hoy.copyWith(hour: 9, minute: 30), motivoRetiro: 'Turno médico'),
      RegistroAsistencia(id: 'r002', alumnoId: '01HX010', alumnoNombre: 'Suárez, Facundo',     cursoId: cursoId, fecha: hoy, horaIngreso: hoy.copyWith(hour: 7, minute: 55), metodoIngreso: MetodoIngreso.nfc,    estado: EstadoAsistencia.presente),
      RegistroAsistencia(id: 'r003', alumnoId: '01HX002', alumnoNombre: 'González, Lucas A.',  cursoId: cursoId, fecha: hoy, horaIngreso: hoy.copyWith(hour: 8, minute:  5), metodoIngreso: MetodoIngreso.manual, estado: EstadoAsistencia.tardanza),
      RegistroAsistencia(id: 'r004', alumnoId: '01HX006', alumnoNombre: 'Acosta, Mateo J.',    cursoId: cursoId, fecha: hoy, horaIngreso: null,                              metodoIngreso: MetodoIngreso.desconocido, estado: EstadoAsistencia.ausente),
      RegistroAsistencia(id: 'r005', alumnoId: '01HX003', alumnoNombre: 'Romero, Diego E.',    cursoId: cursoId, fecha: hoy, horaIngreso: null,                              metodoIngreso: MetodoIngreso.desconocido, estado: EstadoAsistencia.noComputable, esNoComputable: true, motivoNoComputable: 'Superposición horaria (recursante)'),
      RegistroAsistencia(id: 'r006', alumnoId: '01HX005', alumnoNombre: 'Medina, Sofía R.',    cursoId: cursoId, fecha: hoy, horaIngreso: hoy.copyWith(hour: 7, minute: 51), metodoIngreso: MetodoIngreso.nfc,    estado: EstadoAsistencia.presente),
      RegistroAsistencia(id: 'r007', alumnoId: '01HX007', alumnoNombre: 'Ríos, Luciana B.',    cursoId: cursoId, fecha: hoy, horaIngreso: hoy.copyWith(hour: 8, minute: 12), metodoIngreso: MetodoIngreso.qr,     estado: EstadoAsistencia.tardanza),
      RegistroAsistencia(id: 'r008', alumnoId: '01HX009', alumnoNombre: 'Vidal, Camila E.',    cursoId: cursoId, fecha: hoy, horaIngreso: hoy.copyWith(hour: 7, minute: 50), metodoIngreso: MetodoIngreso.nfc,    estado: EstadoAsistencia.presente),
    ];
  }

  // ── Resumen de asistencia ──────────────────────────────────────────────────

  ResumenAsistencia getResumenGlobal(DateTime fecha) => ResumenAsistencia(
    fecha:       fecha,
    presentes:   712,
    ausentes:    88,
    tardanzas:   12,
    noComputables: 6,
    retiros:     5,
    total:       800,
  );

  ResumenAsistencia getResumenTurno(String turno, DateTime fecha) {
    final data = {
      'mañana':     (312, 28, 340),
      'tarde':      (248, 42, 290),
      'vespertino': (152, 18, 170),
    };
    final (p, a, t) = data[turno] ?? (0, 0, 0);
    return ResumenAsistencia(fecha: fecha, presentes: p, ausentes: a, tardanzas: 0, noComputables: 0, retiros: 0, total: t);
  }

  // ── Usuarios ───────────────────────────────────────────────────────────────

  List<Usuario> getUsuarios() => [
    const Usuario(id: 'u001', nombre: 'María',    apellido: 'Rodríguez', username: 'rod.mar', rol: RolUsuario.preceptor, turno: 'Turno Mañana',     activo: true),
    const Usuario(id: 'u002', nombre: 'Carlos',   apellido: 'Pérez',     username: 'per.car', rol: RolUsuario.preceptor, turno: 'Turno Tarde',      activo: true),
    const Usuario(id: 'u003', nombre: 'Lucía',    apellido: 'Gómez',     username: 'gom.luc', rol: RolUsuario.preceptor, turno: 'Turno Vespertino', activo: false),
    const Usuario(id: 'u004', nombre: 'Roberto',  apellido: 'Sánchez',   username: 'san.rob', rol: RolUsuario.preceptor, turno: 'Turno Mañana',     activo: true),
    const Usuario(id: 'u005', nombre: 'Andrea',   apellido: 'López',     username: 'lop.and', rol: RolUsuario.preceptor, turno: 'Turno Tarde',      activo: true),
    const Usuario(id: 'u006', nombre: 'Fernando', apellido: 'Martínez',  username: 'mar.fer', rol: RolUsuario.preceptor, turno: 'Turno Mañana',     activo: false),
    const Usuario(id: 'u007', nombre: 'Admin',    apellido: 'Dirección', username: 'adm.dir', rol: RolUsuario.direccion, turno: null,               activo: true),
  ];
}

extension _DateTimeCopy on DateTime {
  DateTime copyWith({int? hour, int? minute}) =>
      DateTime(year, month, day, hour ?? this.hour, minute ?? this.minute);
}
