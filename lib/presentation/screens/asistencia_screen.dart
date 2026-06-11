import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/registro_asistencia.dart';
import '../../domain/usecases/get_asistencia_diaria.dart';
import '../../infraestructure/datasources/mock_datasource.dart';
import '../../infraestructure/repositories/asistencia_repository_impl.dart';
import '../../infraestructure/repositories/curso_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class AsistenciaScreen extends StatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  late final GetAsistenciaDiaria _getAsistencia;
  late final CursoRepositoryImpl _cursoRepo;

  late Future<(List<Curso>, List<RegistroAsistencia>)> _future;

  Curso? _cursoSeleccionado;
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    final ds = MockDatasource();
    _getAsistencia = GetAsistenciaDiaria(AsistenciaRepositoryImpl(ds));
    _cursoRepo     = CursoRepositoryImpl(ds);
    _loadData();
  }

  void _loadData() {
    _future = Future.wait([
      _cursoRepo.getCursos(),
      if (_cursoSeleccionado != null)
        _getAsistencia(cursoId: _cursoSeleccionado!.id, fecha: _fecha)
      else
        Future.value(<RegistroAsistencia>[]),
    ]).then((results) {
      final cursos    = results[0] as List<Curso>;
      final registros = results[1] as List<RegistroAsistencia>;
      _cursoSeleccionado ??= cursos.isNotEmpty ? cursos.first : null;
      return (cursos, registros);
    });
  }

  void _onCursoChanged(Curso curso) {
    setState(() {
      _cursoSeleccionado = curso;
      _future = _getAsistencia(cursoId: curso.id, fecha: _fecha)
          .then((r) => ([curso] as List<Curso>, r));
      // Recarga completa con nuevo curso
      _loadData();
    });
  }

  void _cambiarFecha(int dias) {
    setState(() {
      _fecha = _fecha.add(Duration(days: dias));
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AAMTopbar(
          title: 'Asistencia',
          actions: [
            const AAMButton(label: 'Ingreso manual', icon: Icons.add_circle_outline),
            const SizedBox(width: 8),
            const AAMButton(label: 'Exportar', icon: Icons.download_outlined, outlined: true),
          ],
        ),
        Expanded(
          child: FutureBuilder<(List<Curso>, List<RegistroAsistencia>)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const AAMLoadingScreen();
              if (snap.hasError) return AAMErrorWidget(
                message: 'Error al cargar asistencia',
                onRetry: () => setState(_loadData),
              );

              final (cursos, registros) = snap.data!;

              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  _buildSelector(cursos),
                  const SizedBox(height: 24),
                  _buildMiniStats(registros),
                  const SizedBox(height: 24),
                  Expanded(child: _buildTabla(registros)),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelector(List<Curso> cursos) {
    final meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final fechaStr = '${dias[_fecha.weekday - 1]} ${_fecha.day} ${meses[_fecha.month - 1]} ${_fecha.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.class_outlined, size: 20, color: AAMColors.primary),
        const SizedBox(width: 12),
        Text('Curso:', style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.textSec)),
        const SizedBox(width: 10),
        if (cursos.isNotEmpty)
          DropdownButton<Curso>(
            value: _cursoSeleccionado,
            underline: const SizedBox.shrink(),
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AAMColors.primary),
            items: cursos.map((c) => DropdownMenuItem(value: c, child: Text(c.nombre))).toList(),
            onChanged: (c) { if (c != null) { _onCursoChanged(c); } },
          ),
        const Spacer(),
        _navBtn(Icons.chevron_left,  () => _cambiarFecha(-1)),
        const SizedBox(width: 10),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: AAMColors.textSec),
          const SizedBox(width: 8),
          Text(fechaStr,
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.primary)),
        ]),
        const SizedBox(width: 10),
        _navBtn(Icons.chevron_right, () => _cambiarFecha(1)),
      ]),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: AAMColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AAMColors.textSec),
      ),
    );
  }

  Widget _buildMiniStats(List<RegistroAsistencia> registros) {
    int count(EstadoAsistencia e) => registros.where((r) => r.estado == e).length;
    final retiros = registros.where((r) => r.tieneRetiroAnticipado).length;

    return Row(children: [
      _MiniStat(label: 'Presentes',      value: '${count(EstadoAsistencia.presente)}',     color: AAMColors.success),
      const SizedBox(width: 12),
      _MiniStat(label: 'Ausentes',       value: '${count(EstadoAsistencia.ausente)}',      color: AAMColors.highlight),
      const SizedBox(width: 12),
      _MiniStat(label: 'Tardanzas',      value: '${count(EstadoAsistencia.tardanza)}',     color: AAMColors.warning),
      const SizedBox(width: 12),
      _MiniStat(label: 'No computables', value: '${count(EstadoAsistencia.noComputable)}', color: AAMColors.accent),
      const SizedBox(width: 12),
      _MiniStat(label: 'Retiros',        value: '$retiros',                                color: AAMColors.primary),
    ]);
  }

  Widget _buildTabla(List<RegistroAsistencia> registros) {
    return Container(
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
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
              ? Center(child: Text('Sin registros para esta fecha',
                  style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.textSec)))
              : ListView.builder(
                  itemCount: registros.length,
                  itemBuilder: (ctx, i) => _RegistroRow(registro: registros[i]),
                ),
        ),
      ]),
    );
  }
}

// ─── Mini stat ────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
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
          Text(value,
            style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
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
  const _RegistroRow({required this.registro});
  final RegistroAsistencia registro;

  @override
  State<_RegistroRow> createState() => _RegistroRowState();
}

class _RegistroRowState extends State<_RegistroRow> {
  bool _hovered = false;

  String _fmtHora(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  (String, Color) get _estadoBadge => switch (widget.registro.estado) {
    EstadoAsistencia.presente     => ('Presente',      AAMColors.success),
    EstadoAsistencia.ausente      => ('Ausente',       AAMColors.highlight),
    EstadoAsistencia.tardanza     => ('Tardanza',      AAMColors.warning),
    EstadoAsistencia.noComputable => ('No computable', AAMColors.accent),
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
          color: _hovered ? AAMColors.surface : AAMColors.white,
          border: const Border(bottom: BorderSide(color: AAMColors.border, width: 1)),
        ),
        child: Row(children: [
          // Alumno
          Expanded(flex: 3, child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: AAMColors.mint,
              child: Text(r.alumnoNombre.substring(0, 1),
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AAMColors.primary)),
            ),
            const SizedBox(width: 10),
            Text(r.alumnoNombre,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AAMColors.primary)),
          ])),
          // Método
          Expanded(flex: 2, child: Row(children: [
            Icon(_metodoIcon(r.metodoIngreso), size: 14, color: AAMColors.textSec),
            const SizedBox(width: 6),
            Text(r.metodoIngreso.label,
              style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec)),
          ])),
          // Ingreso
          Expanded(flex: 2, child: Text(_fmtHora(r.horaIngreso),
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AAMColors.primary))),
          // Retiro
          Expanded(flex: 2, child: Text(_fmtHora(r.horaRetiro),
            style: GoogleFonts.dmSans(fontSize: 13,
              color: r.tieneRetiroAnticipado ? AAMColors.warning : AAMColors.textSec))),
          // Motivo
          Expanded(flex: 2, child: Text(
            r.motivoRetiro ?? r.motivoNoComputable ?? '—',
            style: GoogleFonts.dmSans(fontSize: 11, color: AAMColors.textSec),
            overflow: TextOverflow.ellipsis,
          )),
          // Estado
          Expanded(flex: 2, child: AAMBadge(label: estadoLabel, color: estadoColor)),
          // Acción
          Expanded(flex: 1, child: Icon(Icons.more_horiz, size: 16,
            color: _hovered ? AAMColors.primary : AAMColors.textSec)),
        ]),
      ),
    );
  }

  IconData _metodoIcon(MetodoIngreso m) => switch (m) {
    MetodoIngreso.nfc         => Icons.nfc,
    MetodoIngreso.qr          => Icons.qr_code,
    MetodoIngreso.manual      => Icons.edit_outlined,
    MetodoIngreso.desconocido => Icons.remove,
  };
}
