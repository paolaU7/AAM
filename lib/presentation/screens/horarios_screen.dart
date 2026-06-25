import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/curso.dart';
import '../../infraestructure/datasources/mock_datasource.dart';
import '../../infraestructure/repositories/curso_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class HorariosScreen extends StatefulWidget {
  const HorariosScreen({super.key});

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  late final CursoRepositoryImpl _repo;
  List<Curso> _cursos = [];

  String _cicloLectivo = '2026';
  int? _anioSel;
  String? _divisionSel;
  String? _grupoSel;

  static const List<String> _ciclosLectivos = ['2024', '2025', '2026'];
  static const List<String> _dias   = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];
  static const List<String> _franjas = [
    '07:45 – 08:35', '08:35 – 09:25', '09:25 – 10:15',
    '10:15 – 10:30', // recreo
    '10:30 – 11:20', '11:20 – 12:10', '12:10 – 13:00',
  ];

  // Grilla estática de demo (fi → di → celda)
  static const Map<int, Map<int, _HCelda>> _grilla = {
    0: { 0: _HCelda('Matemática',  '4° 2°', AAMColors.primary), 2: _HCelda('Física',      '3° 1°', AAMColors.accent),   4: _HCelda('Matemática',  '5° 3°', AAMColors.primary) },
    1: { 1: _HCelda('Programación','4° 2°', AAMColors.primary), 3: _HCelda('Electrónica', '3° 1°', AAMColors.accent) },
    2: { 0: _HCelda('Inglés',      '4° 2°', AAMColors.violet), 2: _HCelda('Química',     '5° 3°', AAMColors.violet), 4: _HCelda('Ed. Física', '3° 1°', AAMColors.warning) },
    4: { 0: _HCelda('Proyecto',    '6° 1°', AAMColors.accent),  1: _HCelda('Redes',       '4° 2°', AAMColors.primary), 3: _HCelda('Sistemas',   '6° 1°', AAMColors.accent) },
    5: { 2: _HCelda('Taller',      '4° 2°', AAMColors.success), 4: _HCelda('Taller',      '3° 1°', AAMColors.success) },
    6: { 0: _HCelda('Historia',    '5° 3°', AAMColors.warning),  3: _HCelda('Geografía',   '4° 2°', AAMColors.warning) },
  };

  @override
  void initState() {
    super.initState();
    _repo = CursoRepositoryImpl(MockDatasource());
    _cargarCursos();
  }

  Future<void> _cargarCursos() async {
    final cursos = await _repo.getCursos();
    if (mounted) setState(() => _cursos = cursos);
  }

  List<int> get _anios {
    final s = _cursos.map((c) => c.anio).toSet().toList();
    s.sort();
    return s;
  }

  List<String> get _divisiones {
    if (_anioSel == null) return [];
    final s = _cursos.where((c) => c.anio == _anioSel).map((c) => c.division).toSet().toList();
    s.sort();
    return s;
  }

  List<String> get _grupos {
    if (_anioSel == null || _divisionSel == null) return [];
    final s = _cursos
        .where((c) => c.anio == _anioSel && c.division == _divisionSel)
        .map((c) => c.grupoTaller)
        .toSet()
        .toList();
    s.sort();
    return s;
  }

  Curso? get _cursoResuelto {
    if (_anioSel == null || _divisionSel == null || _grupoSel == null) return null;
    try {
      return _cursos.firstWhere((c) =>
          c.anio == _anioSel && c.division == _divisionSel && c.grupoTaller == _grupoSel);
    } catch (_) {
      return null;
    }
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
          title: 'Horarios',
          actions: [
            const AAMButton(label: 'Cargar Excel', icon: Icons.upload_file_outlined),
            const SizedBox(width: 8),
            const AAMButton(label: 'Exportar', icon: Icons.download_outlined, outlined: true),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              _buildControles(theme),
              const SizedBox(height: 16),
              _buildHint(theme),
              const SizedBox(height: 20),
              Expanded(child: _buildGrilla(theme)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildControles(AAMTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(Icons.schedule_outlined, size: 20, color: theme.text),
        const SizedBox(width: 12),
        _FiltroDropdown<String>(
          label: 'Ciclo lectivo',
          value: _cicloLectivo,
          options: _ciclosLectivos,
          theme: theme,
          onChanged: (v) => setState(() => _cicloLectivo = v ?? _cicloLectivo),
        ),
        const SizedBox(width: 16),
        _FiltroDropdown<int>(
          label: 'Año',
          value: _anioSel,
          options: _anios,
          theme: theme,
          itemLabel: (a) => '$a°',
          onChanged: (v) => setState(() {
            _anioSel = v;
            _divisionSel = null;
            _grupoSel = null;
          }),
        ),
        const SizedBox(width: 16),
        _FiltroDropdown<String>(
          label: 'División',
          value: _divisionSel,
          options: _divisiones,
          theme: theme,
          onChanged: _anioSel == null ? null : (v) => setState(() {
            _divisionSel = v;
            _grupoSel = null;
          }),
        ),
        const SizedBox(width: 16),
        _FiltroDropdown<String>(
          label: 'Grupo de taller',
          value: _grupoSel,
          options: _grupos,
          theme: theme,
          onChanged: _divisionSel == null ? null : (v) => setState(() => _grupoSel = v),
        ),
        if (_cursoResuelto != null) ...
          [
            const SizedBox(width: 16),
            Text(
              '$_anioSel° $_divisionSel (${_cursoResuelto!.especialidad})',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
            ),
          ],
        const Spacer(),
        _Leyenda(color: AAMColors.primary, label: 'Curricular'),
        const SizedBox(width: 12),
        _Leyenda(color: AAMColors.accent,  label: 'Taller'),
        const SizedBox(width: 12),
        _Leyenda(color: AAMColors.success, label: 'Almuerzo'),
        const SizedBox(width: 12),
        _Leyenda(color: AAMColors.mint,    label: 'Recreo'),
        const SizedBox(width: 12),
        _Leyenda(color: AAMColors.warning, label: 'Ed. Física'),
      ]),
    );
  }

  Widget _buildHint(AAMTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AAMColors.mint.withAlpha((0.3 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AAMColors.accent.withAlpha((0.3 * 255).round())),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 18, color: AAMColors.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Los horarios se cargan mediante Excel estandarizado. '
          'El sistema valida el formato antes de procesar.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.primary),
        )),
        const AAMButton(label: 'Descargar plantilla', outlined: true),
      ]),
    );
  }

  Widget _buildGrilla(AAMTheme theme) {
    const double colW = 140;
    const double rowH = 56;
    const double hdrH = 44;

    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 80 + colW * _dias.length,
            child: Column(children: [
              // Header
              Container(
                height: hdrH,
                color: theme.surfaceCol,
                child: Row(children: [
                  const SizedBox(width: 80),
                  ..._dias.map((d) => SizedBox(
                    width: colW,
                    child: Center(child: Text(d,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text))),
                  )),
                ]),
              ),
              Divider(height: 1, color: theme.borderCol),
              // Filas
              Expanded(child: ListView.builder(
                itemCount: _franjas.length,
                itemBuilder: (ctx, fi) {
                  final esRecreo = _franjas[fi].contains('10:15');
                  return Container(
                    height: esRecreo ? 32 : rowH,
                    decoration: BoxDecoration(
                      color: esRecreo ? theme.surfaceCol : theme.card,
                      border: Border(bottom: BorderSide(color: theme.borderCol, width: 1)),
                    ),
                    child: Row(children: [
                      SizedBox(width: 80, child: Center(child: Text(_franjas[fi],
                        style: GoogleFonts.dmSans(
                          fontSize: esRecreo ? 10 : 11,
                          color: esRecreo ? AAMColors.accent : theme.textSec,
                          fontWeight: esRecreo ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center))),
                      ..._dias.asMap().entries.map((e) {
                        final celda = _grilla[fi]?[e.key];
                        return SizedBox(
                          width: colW,
                          child: esRecreo
                              ? Container(color: AAMColors.mint.withOpacity(0.25),
                                  child: Center(child: Text('— Recreo —',
                                    style: GoogleFonts.dmSans(fontSize: 10, color: AAMColors.accent, fontWeight: FontWeight.w600))))
                              : celda != null
                                  ? _CeldaHorario(celda: celda, theme: theme)
                                  : Container(margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8))),
                        );
                      }),
                    ]),
                  );
                },
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HCelda {
  const _HCelda(this.materia, this.curso, this.color);
  final String materia;
  final String curso;
  final Color color;
}

class _CeldaHorario extends StatefulWidget {
  const _CeldaHorario({required this.celda, required this.theme});
  final _HCelda celda;
  final AAMTheme theme;

  @override
  State<_CeldaHorario> createState() => _CeldaHorarioState();
}

class _CeldaHorarioState extends State<_CeldaHorario> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _hovered ? widget.celda.color : widget.celda.color.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(widget.celda.materia,
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
              color: _hovered ? AAMColors.white : widget.celda.color),
            overflow: TextOverflow.ellipsis),
          Text(widget.celda.curso,
            style: GoogleFonts.dmSans(fontSize: 10,
              color: _hovered ? AAMColors.white.withAlpha((0.8 * 255).round()) : widget.theme.textSec)),
        ]),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AAMColors.textSec)),
    ]);
  }
}

class _FiltroDropdown<T> extends StatelessWidget {
  const _FiltroDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.theme,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final T? value;
  final List<T> options;
  final AAMTheme theme;
  final ValueChanged<T?>? onChanged;
  final String Function(T)? itemLabel;

  @override
  Widget build(BuildContext context) {
    final habilitado = onChanged != null && options.isNotEmpty;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label:', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
      const SizedBox(width: 8),
      DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        hint: Text('—', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(itemLabel != null ? itemLabel!(o) : o.toString()))).toList(),
        onChanged: habilitado ? onChanged : null,
      ),
    ]);
  }
}
