import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/aam_design_system.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  static const List<_ReporteConfig> _reportes = [
    _ReporteConfig(icon: Icons.calendar_today_outlined,  color: AAMColors.primary,       titulo: 'Asistencia diaria',    descripcion: 'Presentes, ausentes y tardanzas del día seleccionado.',          badge: 'PDF / Excel'),
    _ReporteConfig(icon: Icons.bar_chart_outlined,       color: AAMColors.accent,        titulo: 'Resumen mensual',      descripcion: 'Porcentaje por curso y turno. Comparativo mes a mes.',             badge: 'Excel'),
    _ReporteConfig(icon: Icons.person_off_outlined,      color: AAMColors.violet,        titulo: 'Alumnos en riesgo',    descripcion: 'Alumnos con asistencia bajo el umbral RITE (75%).',               badge: 'PDF'),
    _ReporteConfig(icon: Icons.exit_to_app_outlined,     color: AAMColors.warning,       titulo: 'Retiros anticipados',  descripcion: 'Registro de retiros con hora, motivo y responsable.',             badge: 'Excel'),
    _ReporteConfig(icon: Icons.repeat_outlined,          color: AAMColors.violet,        titulo: 'No computables',       descripcion: 'Registros marcados como no computables con motivo y docente.',    badge: 'PDF / Excel'),
    _ReporteConfig(icon: Icons.nfc,                      color: AAMColors.success,       titulo: 'Actividad NFC',        descripcion: 'Log de lecturas por ESP32. Detecta anomalías de sincronización.', badge: 'Excel'),
  ];

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
        const AAMTopbar(title: 'Reportes'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reportes y exportaciones',
                style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: theme.text)),
              const SizedBox(height: 6),
              Text('Generá reportes en Excel o PDF sobre asistencia, alumnos y cursos.',
                style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
              const SizedBox(height: 28),
              Wrap(
                spacing: 20, runSpacing: 20,
                children: _reportes.map((r) => _ReporteCard(config: r, theme: theme)).toList(),
              ),
              const SizedBox(height: 32),
              Text('Exportación personalizada',
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
              const SizedBox(height: 16),
              _buildCustomExport(theme),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomExport(AAMTheme theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Configurá los filtros y generá un reporte a medida.',
          style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12, runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _FilterField(label: 'Desde', hint: '01/06/2026', theme: theme),
            _FilterField(label: 'Hasta', hint: '30/06/2026', theme: theme),
            _FilterDropdown(label: 'Curso', items: const ['Todos', '4° 2°', '3° 1°', '5° 3°'], theme: theme),
            _FilterDropdown(label: 'Turno', items: const ['Todos', 'Mañana', 'Tarde', 'Vespertino'], theme: theme),
            const AAMButton(label: 'Generar Excel', icon: Icons.download_outlined),
            const AAMButton(label: 'Generar PDF',   icon: Icons.picture_as_pdf_outlined, outlined: true),
          ],
        ),
      ]),
    );
  }
}

// ─── Reporte card ─────────────────────────────────────────────────────────────
class _ReporteConfig {
  const _ReporteConfig({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.descripcion,
    required this.badge,
  });
  final IconData icon;
  final Color color;
  final String titulo;
  final String descripcion;
  final String badge;
}

class _ReporteCard extends StatefulWidget {
  const _ReporteCard({required this.config, required this.theme});
  final _ReporteConfig config;
  final AAMTheme theme;

  @override
  State<_ReporteCard> createState() => _ReporteCardState();
}

class _ReporteCardState extends State<_ReporteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hovered ? widget.theme.surfaceCol : widget.theme.card,
          border: Border.all(color: _hovered ? c.color : widget.theme.borderCol),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: c.color.withAlpha(_hovered ? 77 : 31),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(c.icon, size: 20, color: _hovered ? widget.theme.text : c.color),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _hovered ? widget.theme.inputBg : AAMColors.mint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(c.badge,
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
                  color: _hovered ? widget.theme.text : c.color)),
            ),
          ]),
          const SizedBox(height: 16),
          Text(c.titulo,
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700,
              color: _hovered ? widget.theme.text : c.color)),
          const SizedBox(height: 6),
          Text(c.descripcion,
            style: GoogleFonts.dmSans(fontSize: 12,
              color: _hovered ? widget.theme.text : widget.theme.textSec)),
          const SizedBox(height: 16),
          Row(children: [
            const Spacer(),
            Icon(Icons.arrow_forward, size: 16, color: _hovered ? widget.theme.text : widget.theme.textSec),
          ]),
        ]),
      ),
    );
  }
}

// ─── Filtros ──────────────────────────────────────────────────────────────────
class _FilterField extends StatelessWidget {
  const _FilterField({required this.label, required this.hint, required this.theme});
  final String label;
  final String hint;
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: theme.textSec)),
      const SizedBox(height: 4),
      Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: theme.borderCol),
          borderRadius: BorderRadius.circular(8),
          color: theme.inputBg,
        ),
        child: Text(hint, style: GoogleFonts.dmSans(fontSize: 13, color: theme.text)),
      ),
    ]);
  }
}

class _FilterDropdown extends StatefulWidget {
  const _FilterDropdown({required this.label, required this.items, required this.theme});
  final String label;
  final List<String> items;
  final AAMTheme theme;

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> {
  late String _selected = widget.items.first;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: widget.theme.textSec)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: widget.theme.borderCol),
          borderRadius: BorderRadius.circular(8),
          color: widget.theme.inputBg,
        ),
        child: DropdownButton<String>(
          value: _selected,
          underline: const SizedBox.shrink(),
          style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.text),
          items: widget.items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: GoogleFonts.dmSans(color: widget.theme.text)))).toList(),
          onChanged: (v) => setState(() => _selected = v ?? _selected),
        ),
      ),
    ]);
  }
}
