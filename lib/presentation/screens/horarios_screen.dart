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
  String _especialidad = 'Informática';

  static const List<String> _especialidades = ['Informática', 'Electrónica', 'Construcciones'];
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
    2: { 0: _HCelda('Inglés',      '4° 2°', Color(0xFF7C3AED)), 2: _HCelda('Química',     '5° 3°', Color(0xFF7C3AED)), 4: _HCelda('Ed. Física', '3° 1°', AAMColors.warning) },
    4: { 0: _HCelda('Proyecto',    '6° 1°', AAMColors.accent),  1: _HCelda('Redes',       '4° 2°', AAMColors.primary), 3: _HCelda('Sistemas',   '6° 1°', AAMColors.accent) },
    5: { 2: _HCelda('Taller',      '4° 2°', AAMColors.success), 4: _HCelda('Taller',      '3° 1°', AAMColors.success) },
    6: { 0: _HCelda('Historia',    '5° 3°', AAMColors.warning),  3: _HCelda('Geografía',   '4° 2°', AAMColors.warning) },
  };

  @override
  void initState() {
    super.initState();
    _repo   = CursoRepositoryImpl(MockDatasource());
  }

  @override
  Widget build(BuildContext context) {
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
              _buildControles(),
              const SizedBox(height: 16),
              _buildHint(),
              const SizedBox(height: 20),
              Expanded(child: _buildGrilla()),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildControles() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.schedule_outlined, size: 20, color: AAMColors.primary),
        const SizedBox(width: 12),
        Text('Especialidad:', style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.textSec)),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _especialidad,
          underline: const SizedBox.shrink(),
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AAMColors.primary),
          items: _especialidades.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _especialidad = v ?? _especialidad),
        ),
        const SizedBox(width: 24),
        Text('Ciclo lectivo 2026',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AAMColors.primary)),
        const Spacer(),
        _Leyenda(color: AAMColors.primary,       label: 'Teórica'),
        const SizedBox(width: 12),
        _Leyenda(color: AAMColors.accent,        label: 'Taller'),
        const SizedBox(width: 12),
        _Leyenda(color: AAMColors.success,       label: 'Lab.'),
        const SizedBox(width: 12),
        _Leyenda(color: AAMColors.warning,       label: 'Ed. Física / Gral.'),
      ]),
    );
  }

  Widget _buildHint() {
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

  Widget _buildGrilla() {
    const double colW = 140;
    const double rowH = 56;
    const double hdrH = 44;

    return Container(
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
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
                color: AAMColors.surface,
                child: Row(children: [
                  const SizedBox(width: 80),
                  ..._dias.map((d) => SizedBox(
                    width: colW,
                    child: Center(child: Text(d,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AAMColors.primary))),
                  )),
                ]),
              ),
              const Divider(height: 1, color: AAMColors.border),
              // Filas
              Expanded(child: ListView.builder(
                itemCount: _franjas.length,
                itemBuilder: (ctx, fi) {
                  final esRecreo = _franjas[fi].contains('10:15');
                  return Container(
                    height: esRecreo ? 32 : rowH,
                    decoration: BoxDecoration(
                      color: esRecreo ? AAMColors.surface : AAMColors.white,
                      border: const Border(bottom: BorderSide(color: AAMColors.border, width: 1)),
                    ),
                    child: Row(children: [
                      SizedBox(width: 80, child: Center(child: Text(_franjas[fi],
                        style: GoogleFonts.dmSans(
                          fontSize: esRecreo ? 10 : 11,
                          color: esRecreo ? AAMColors.accent : AAMColors.textSec,
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
                                  ? _CeldaHorario(celda: celda)
                                  : Container(margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: AAMColors.surface, borderRadius: BorderRadius.circular(8))),
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
  const _CeldaHorario({required this.celda});
  final _HCelda celda;

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
              color: _hovered ? AAMColors.white.withAlpha((0.8 * 255).round()) : AAMColors.textSec)),
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
