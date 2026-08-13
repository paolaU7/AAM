import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/usecases/get_daily_attendance.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../../infrastructure/repositories/attendance_repository_impl.dart';
import '../../infrastructure/repositories/course_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class AsistenciaScreen extends StatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  late final ApiDatasource _ds;
  late final GetDailyAttendance _getAsistencia;
  late final CourseRepositoryImpl _cursoRepo;
  late final AttendanceRepositoryImpl _asistenciaRepo;

  late Future<(List<Course>, List<AttendanceRecord>)> _future;

  Course? _cursoSeleccionado;
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ds = ApiDatasource();
    _asistenciaRepo = AttendanceRepositoryImpl(_ds);
    _getAsistencia  = GetDailyAttendance(_asistenciaRepo);
    _cursoRepo      = CourseRepositoryImpl(_ds);
    _loadData();
  }

  void _loadData() {
    _future = Future.wait([
      _cursoRepo.getCourses(),
      if (_cursoSeleccionado != null)
        _getAsistencia(courseId: _cursoSeleccionado!.id, date: _fecha)
      else
        Future.value(<AttendanceRecord>[]),
    ]).then((results) {
      final cursos    = results[0] as List<Course>;
      final registros = results[1] as List<AttendanceRecord>;
      _cursoSeleccionado ??= cursos.isNotEmpty ? cursos.first : null;
      return (cursos, registros);
    });
  }

  void _onCursoChanged(Course curso) {
    setState(() {
      _cursoSeleccionado = curso;
      _loadData();
    });
  }

  void _cambiarFecha(int dias) {
    setState(() {
      _fecha = _fecha.add(Duration(days: dias));
      _loadData();
    });
  }

  // ── Modales ────────────────────────────────────────────────────────────────

  void _abrirIngresoManual() {
    if (_cursoSeleccionado == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _IngresoManualModal(
        curso: _cursoSeleccionado!,
        fecha: _fecha,
        datasource: _ds,
        onConfirm: (studentId, entryTimestamp, status) async {
          await _asistenciaRepo.registerManualCheckIn(
            studentId:      studentId,
            courseId:       _cursoSeleccionado!.id,
            entryTimestamp: entryTimestamp,
            status:         status,
          );
          setState(_loadData);
        },
      ),
    );
  }

  void _abrirRetiroAnticipado(AttendanceRecord registro) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _RetiroAnticipadoModal(
        registro: registro,
        datasource: _ds,
        onConfirm: (motivo, registradoPor) async {
          await _asistenciaRepo.registerEarlyDeparture(
            recordId:            registro.id,
            departureTime:       DateTime.now(),
            reason:              motivo,
            registeredByUserId:  registradoPor,
          );
          setState(_loadData);
        },
      ),
    );
  }

  void _abrirNoComputable(AttendanceRecord registro) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NoComputableModal(
        registro: registro,
        onConfirm: () async {
          await _asistenciaRepo.markNonComputable(registro.id);
          setState(_loadData);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return _buildScreen(theme);
      },
    );
  }

  Widget _buildScreen(AAMTheme theme) {
    return Column(
      children: [
        AAMTopbar(
          title: 'Asistencia',
          actions: [
            AAMButton(label: 'Ingreso manual', icon: Icons.add_circle_outline, onPressed: _abrirIngresoManual),
            const SizedBox(width: 8),
            const AAMButton(label: 'Exportar', icon: Icons.download_outlined, outlined: true),
          ],
        ),
        Expanded(
          child: FutureBuilder<(List<Course>, List<AttendanceRecord>)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const AAMLoadingScreen();
              }
              if (snap.hasError) {
                return AAMErrorWidget(
                  message: 'Error al cargar asistencia',
                  onRetry: () => setState(_loadData),
                );
              }

              final (cursos, registros) = snap.data!;

              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  _buildSelector(cursos, theme),
                  const SizedBox(height: 24),
                  _buildMiniStats(registros),
                  const SizedBox(height: 24),
                  Expanded(child: _buildTabla(registros, theme)),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelector(List<Course> cursos, AAMTheme theme) {
    final meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final fechaStr = '${dias[_fecha.weekday - 1]} ${_fecha.day} ${meses[_fecha.month - 1]} ${_fecha.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(Icons.class_outlined, size: 20, color: theme.text),
        const SizedBox(width: 12),
        Text('Curso:', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
        const SizedBox(width: 10),
        if (cursos.isEmpty)
          Text('Sin cursos cargados', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec))
        else
          DropdownButton<Course>(
            value: _cursoSeleccionado,
            underline: const SizedBox.shrink(),
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text),
            items: cursos.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (c) { if (c != null) _onCursoChanged(c); },
          ),
        const Spacer(),
        _navBtn(Icons.chevron_left,  () => _cambiarFecha(-1), theme),
        const SizedBox(width: 10),
        Row(children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: theme.textSec),
          const SizedBox(width: 8),
          Text(fechaStr,
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: theme.text)),
        ]),
        const SizedBox(width: 10),
        _navBtn(Icons.chevron_right, () => _cambiarFecha(1), theme),
      ]),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, AAMTheme theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: theme.borderCol),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: theme.textSec),
      ),
    );
  }

  Widget _buildMiniStats(List<AttendanceRecord> registros) {
    int count(AttendanceStatus e) => registros.where((r) => r.status == e).length;
    final ausentes = count(AttendanceStatus.absent) + count(AttendanceStatus.absentWithPresence);
    final retiros = registros.where((r) => r.hasEarlyDeparture).length;

    return Row(children: [
      _MiniStat(label: 'Presentes',      value: '${count(AttendanceStatus.present)}', color: AAMColors.success),
      const SizedBox(width: 12),
      _MiniStat(label: 'Ausentes',       value: '$ausentes',                          color: AAMColors.danger),
      const SizedBox(width: 12),
      _MiniStat(label: 'Tardanzas',      value: '${count(AttendanceStatus.late)}',    color: AAMColors.warning),
      const SizedBox(width: 12),
      _MiniStat(label: 'No computables', value: '${count(AttendanceStatus.nonComputableAbsence)}', color: AAMColors.accent),
      const SizedBox(width: 12),
      _MiniStat(label: 'Retiros',        value: '$retiros', color: AAMColors.primary),
    ]);
  }

  Widget _buildTabla(List<AttendanceRecord> registros, AAMTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const AAMTableHeader(columns: [
          ('Alumno',  3),
          ('Método',  2),
          ('Ingreso', 2),
          ('Retiro',  2),
          ('Motivo',  2),
          ('Estado',  2),
          ('',        1),
        ]),
        Expanded(
          child: registros.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fact_check_outlined, size: 40, color: theme.borderCol),
                    const SizedBox(height: 12),
                    Text('Sin registros para esta fecha',
                      style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
                    const SizedBox(height: 8),
                    AAMButton(label: 'Registrar ingreso manual', onPressed: _abrirIngresoManual),
                  ],
                ))
              : ListView.builder(
                  itemCount: registros.length,
                  itemBuilder: (ctx, i) => _RegistroRow(
                    registro: registros[i],
                    theme: theme,
                    onRetiro:      () => _abrirRetiroAnticipado(registros[i]),
                    onNoComputable: () => _abrirNoComputable(registros[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ─── Mini stat ────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha((0.08 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha((0.15 * 255).round())),
        ),
        child: Row(children: [
          Text(value, style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Flexible(child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.textSec),
            overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

// ─── Fila de registro ─────────────────────────────────────────────────────────
class _RegistroRow extends StatefulWidget {
  const _RegistroRow({
    required this.registro,
    required this.theme,
    required this.onRetiro,
    required this.onNoComputable,
  });
  final AttendanceRecord registro;
  final AAMTheme theme;
  final VoidCallback onRetiro;
  final VoidCallback onNoComputable;

  @override
  State<_RegistroRow> createState() => _RegistroRowState();
}

class _RegistroRowState extends State<_RegistroRow> {
  bool _hovered = false;

  String _fmtHora(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  (String, Color) get _estadoBadge => switch (widget.registro.status) {
    AttendanceStatus.present              => ('Presente',                 AAMColors.success),
    AttendanceStatus.absent               => ('Ausente',                  AAMColors.danger),
    AttendanceStatus.late                 => ('Tardanza',                 AAMColors.warning),
    AttendanceStatus.absentWithPresence   => ('Ausente con permanencia',  AAMColors.danger),
    AttendanceStatus.nonComputableAbsence => ('No computable',            AAMColors.accent),
  };

  @override
  Widget build(BuildContext context) {
    final r = widget.registro;
    final (estadoLabel, estadoColor) = _estadoBadge;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: _hovered ? widget.theme.surfaceCol : widget.theme.card,
          border: Border(bottom: BorderSide(color: widget.theme.borderCol, width: 1)),
        ),
        child: Row(children: [
          // Alumno
          Expanded(flex: 3, child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: AAMColors.mint,
              child: Text(r.studentName.isNotEmpty ? r.studentName.substring(0, 1) : '?',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: widget.theme.text)),
            ),
            const SizedBox(width: 10),
            Text(r.studentName,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text)),
          ])),
          // Método
          Expanded(flex: 2, child: Row(children: [
            Icon(_metodoIcon(r.source), size: 14, color: widget.theme.textSec),
            const SizedBox(width: 6),
            Text(r.source.label,
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec)),
          ])),
          // Ingreso
          Expanded(flex: 2, child: Text(_fmtHora(r.entryTimestamp),
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text))),
          // Retiro
          Expanded(flex: 2, child: Text(_fmtHora(r.departureTime),
            style: GoogleFonts.dmSans(fontSize: 13,
              color: r.hasEarlyDeparture ? AAMColors.warning : widget.theme.textSec))),
          // Motivo
          Expanded(flex: 2, child: Text(
            r.departureReason ?? '—',
            style: GoogleFonts.dmSans(fontSize: 11, color: widget.theme.textSec),
            overflow: TextOverflow.ellipsis,
          )),
          // Estado
          Expanded(flex: 2, child: AAMBadge(label: estadoLabel, color: estadoColor)),
          // Acciones
          Expanded(flex: 1, child: _hovered
              ? Row(children: [
                  _ActionBtn(
                    icon: Icons.exit_to_app_outlined,
                    color: AAMColors.warning,
                    tooltip: 'Retiro anticipado',
                    onTap: widget.onRetiro,
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.remove_circle_outline,
                    color: AAMColors.accent,
                    tooltip: 'No computable',
                    onTap: widget.onNoComputable,
                  ),
                ])
              : Icon(Icons.more_horiz, size: 16, color: widget.theme.borderCol)),
        ]),
      ),
    );
  }

  IconData _metodoIcon(AttendanceSource m) => switch (m) {
    AttendanceSource.nfc     => Icons.nfc,
    AttendanceSource.qr      => Icons.qr_code,
    AttendanceSource.manual  => Icons.edit_outlined,
  };
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

// ─── Modal: ingreso manual ────────────────────────────────────────────────────
class _IngresoManualModal extends StatefulWidget {
  const _IngresoManualModal({
    required this.curso,
    required this.fecha,
    required this.datasource,
    required this.onConfirm,
  });
  final Course curso;
  final DateTime fecha;
  final ApiDatasource datasource;
  final Future<void> Function(String studentId, DateTime entryTimestamp, AttendanceStatus status) onConfirm;

  @override
  State<_IngresoManualModal> createState() => _IngresoManualModalState();
}

class _IngresoManualModalState extends State<_IngresoManualModal> {
  List<Student> _alumnos = [];
  Student? _alumnoSel;
  AttendanceStatus _estado = AttendanceStatus.present;
  TimeOfDay _hora   = TimeOfDay.now();
  bool _alumnosLoading = true;
  bool _loading     = false;
  String? _error;

  static const List<AttendanceStatus> _estadosDisponibles = [
    AttendanceStatus.present,
    AttendanceStatus.late,
    AttendanceStatus.absent,
    AttendanceStatus.absentWithPresence,
  ];

  @override
  void initState() {
    super.initState();
    _cargarAlumnos();
  }

  Future<void> _cargarAlumnos() async {
    setState(() { _alumnosLoading = true; _error = null; });
    try {
      final todos = await widget.datasource.getAlumnos();
      final delCurso = todos.where((a) => a.cursoId == widget.curso.id).toList()
        ..sort((a, b) => a.apellido.compareTo(b.apellido));
      if (mounted) setState(() => _alumnos = delCurso);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los alumnos del curso.');
    } finally {
      if (mounted) setState(() => _alumnosLoading = false);
    }
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(context: context, initialTime: _hora);
    if (picked != null) setState(() => _hora = picked);
  }

  Future<void> _submit() async {
    final alumno = _alumnoSel;
    if (alumno == null) {
      setState(() => _error = 'Seleccioná un alumno.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final horaCompleta = DateTime(
        widget.fecha.year, widget.fecha.month, widget.fecha.day,
        _hora.hour, _hora.minute,
      );
      await widget.onConfirm(alumno.id, horaCompleta, _estado);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_circle_outline, size: 18, color: AAMColors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ingreso manual', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
                  Text(widget.curso.name, style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close, size: 16, color: theme.textSec)),
                ),
              ]),
              const SizedBox(height: 24),

              // Alumno (del curso seleccionado)
              Text('Alumno', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
              const SizedBox(height: 6),
              _dropdownContainer(
                theme,
                enabled: !_alumnosLoading && _alumnos.isNotEmpty,
                child: DropdownButton<Student>(
                  value: _alumnoSel,
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  hint: Text(
                    _alumnosLoading
                        ? 'Cargando...'
                        : (_alumnos.isEmpty ? 'Sin alumnos en este curso' : 'Seleccionar alumno'),
                    style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
                  ),
                  style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
                  items: _alumnos.map((a) => DropdownMenuItem(value: a, child: Text(a.nombreCompleto))).toList(),
                  onChanged: (_alumnosLoading || _alumnos.isEmpty) ? null : (v) => setState(() => _alumnoSel = v),
                ),
              ),
              const SizedBox(height: 16),

              // Estado
              Text('Estado', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
              const SizedBox(height: 6),
              _dropdownContainer(
                theme,
                enabled: true,
                child: DropdownButton<AttendanceStatus>(
                  value: _estado,
                  underline: const SizedBox.shrink(),
                  isExpanded: true,
                  style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
                  items: _estadosDisponibles.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                  onChanged: (v) => setState(() => _estado = v ?? _estado),
                ),
              ),
              const SizedBox(height: 16),

              // Hora
              Text('Hora de ingreso', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickHora,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.borderCol),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.schedule_outlined, size: 18, color: theme.textSec),
                    const SizedBox(width: 10),
                    Text(_hora.format(context),
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: theme.text)),
                    const Spacer(),
                    Icon(Icons.edit_outlined, size: 14, color: theme.textSec),
                  ]),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AAMColors.danger.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 14, color: AAMColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger))),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textSec))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: _loading ? AAMColors.accent.withAlpha((0.6 * 255).round()) : AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: Center(child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                        : Text('Registrar', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
                  ),
                )),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _dropdownContainer(AAMTheme theme, {required bool enabled, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

// ─── Modal: retiro anticipado ─────────────────────────────────────────────────
class _RetiroAnticipadoModal extends StatefulWidget {
  const _RetiroAnticipadoModal({required this.registro, required this.datasource, required this.onConfirm});
  final AttendanceRecord registro;
  final ApiDatasource datasource;
  final Future<void> Function(String motivo, String registradoPorUserId) onConfirm;

  @override
  State<_RetiroAnticipadoModal> createState() => _RetiroAnticipadoModalState();
}

class _RetiroAnticipadoModalState extends State<_RetiroAnticipadoModal> {
  final _motivoCtrl = TextEditingController();
  List<User> _usuarios = [];
  User? _usuarioSel;
  bool _usuariosLoading = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  @override
  void dispose() { _motivoCtrl.dispose(); super.dispose(); }

  Future<void> _cargarUsuarios() async {
    setState(() { _usuariosLoading = true; _error = null; });
    try {
      final usuarios = await widget.datasource.getUsers();
      if (mounted) setState(() => _usuarios = usuarios);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los usuarios.');
    } finally {
      if (mounted) setState(() => _usuariosLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_motivoCtrl.text.isEmpty) {
      setState(() => _error = 'Ingresá el motivo del retiro.');
      return;
    }
    final registradoPor = _usuarioSel;
    if (registradoPor == null) {
      setState(() => _error = 'Seleccioná quién registra el retiro.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onConfirm(_motivoCtrl.text.trim(), registradoPor.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now();
    final horaStr = '${hora.hour.toString().padLeft(2, "0")}${hora.minute.toString().padLeft(2, "0")}';

    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AAMColors.warning, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.exit_to_app_outlined, size: 18, color: AAMColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Retiro anticipado', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
              Text(widget.registro.studentName, style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
            ])),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.close, size: 16, color: theme.textSec)),
            ),
          ]),
          const SizedBox(height: 20),

          // Hora actual (no editable, se registra automáticamente)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.schedule_outlined, size: 16, color: theme.textSec),
              const SizedBox(width: 8),
              Text('Hora de salida: ', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
              Text(horaStr, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AAMColors.warning)),
              const Spacer(),
              Text('Ahora', style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
            ]),
          ),
          const SizedBox(height: 16),

          Text('Motivo', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
            child: TextField(
              controller: _motivoCtrl,
              maxLines: 3,
              style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
              decoration: InputDecoration(
                hintText: 'Ej: Turno médico, problema familiar...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Registrado por', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
            child: DropdownButton<User>(
              value: _usuarioSel,
              underline: const SizedBox.shrink(),
              isExpanded: true,
              hint: Text(_usuariosLoading ? 'Cargando...' : 'Seleccionar preceptor/dirección',
                style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
              style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
              items: _usuarios.map((u) => DropdownMenuItem(value: u, child: Text(u.fullName))).toList(),
              onChanged: _usuariosLoading ? null : (v) => setState(() => _usuarioSel = v),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AAMColors.danger.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 14, color: AAMColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger))),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textSec))),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _loading ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _loading ? AAMColors.warning.withAlpha((0.6 * 255).round()) : AAMColors.warning, borderRadius: BorderRadius.circular(10)),
                child: Center(child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                    : Text('Registrar retiro', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
              ),
            )),
          ]),
        ]),
      ),
    );
      },
    );
  }
}

// ─── Modal: no computable ─────────────────────────────────────────────────────
class _NoComputableModal extends StatefulWidget {
  const _NoComputableModal({required this.registro, required this.onConfirm});
  final AttendanceRecord registro;
  final Future<void> Function() onConfirm;

  @override
  State<_NoComputableModal> createState() => _NoComputableModalState();
}

class _NoComputableModalState extends State<_NoComputableModal> {
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.remove_circle_outline, size: 18, color: AAMColors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Marcar no computable', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
                  Text(widget.registro.studentName, style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close, size: 16, color: theme.textSec)),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AAMColors.accent.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 14, color: AAMColors.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'La falta no afectará el cálculo del RITE del alumno. '
                    'El schema no guarda un motivo de texto para esto — solo cambia el estado.',
                    style: GoogleFonts.dmSans(fontSize: 12, color: theme.text))),
                ]),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AAMColors.danger.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 14, color: AAMColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger))),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textSec))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: _loading ? AAMColors.accent.withAlpha((0.6 * 255).round()) : AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: Center(child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                        : Text('Confirmar', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
                  ),
                )),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
