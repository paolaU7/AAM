import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/config.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../widgets/aam_design_system.dart';

/// Sección "Configuración" del Panel de Dirección, en tres sub-pestañas:
///
///   General → alertas del panel + almuerzo + turnos (etiqueta) + recreos.
///   Cursos  → estructura académica: cantidad de años, divisiones por año,
///             grupos de taller por curso, y el año lectivo actual.
///   Dispositivos → puntos de acceso + lectores NFC.
///
/// No usa AutoRefreshMixin: son formularios con cambios sin guardar. Cada
/// sub-pestaña recarga al entrar y después de cada operación.
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  int _section = 0;

  static const _tabs = <({IconData icon, String label})>[
    (icon: Icons.tune, label: 'General'),
    (icon: Icons.school_outlined, label: 'Cursos'),
    (icon: Icons.nfc, label: 'Dispositivos'),
  ];

  Widget get _current => switch (_section) {
        0 => const _GeneralSection(),
        1 => const _CursosSection(),
        2 => const _DispositivosSection(),
        _ => const _GeneralSection(),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Column(children: [
          const AAMTopbar(title: 'Configuración'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: theme.card,
              border: Border(bottom: BorderSide(color: theme.borderCol, width: 1)),
            ),
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SectionTab(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: _section == i,
                    onTap: () => setState(() => _section = i),
                    theme: theme,
                  ),
                ),
            ]),
          ),
          Expanded(child: _current),
        ]);
      },
    );
  }
}

class _SectionTab extends StatefulWidget {
  const _SectionTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AAMTheme theme;

  @override
  State<_SectionTab> createState() => _SectionTabState();
}

class _SectionTabState extends State<_SectionTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final fg = widget.selected ? AAMColors.white : (_hovered ? AAMColors.primary : t.textSec);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected ? AAMColors.primary : (_hovered ? t.surfaceCol : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                )),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  General
// ═══════════════════════════════════════════════════════════════════════════

class _GeneralSection extends StatefulWidget {
  const _GeneralSection();

  @override
  State<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<_GeneralSection> {
  final ApiDatasource _ds = ApiDatasource();

  bool _loading = true;
  String? _loadError;

  // Alertas + almuerzo (school_settings).
  final _absences = TextEditingController();
  final _preceptorDays = TextEditingController();
  final _exceptionDays = TextEditingController();
  String _lunchStart = '11:50';
  String _lunchStartFifth = '12:50';
  String _lunchEnd = '13:10';
  bool _savingSettings = false;
  String? _settingsError;
  bool _settingsSaved = false;

  // Turnos.
  List<ShiftConfig> _shifts = [];
  final Map<String, TextEditingController> _shiftCtrls = {};

  // Recreos.
  String _breakShift = 'morning';
  List<ShiftBreak> _breaks = [];
  bool _breaksLoading = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _absences.dispose();
    _preceptorDays.dispose();
    _exceptionDays.dispose();
    for (final c in _shiftCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([_ds.getConfigSchoolSettings(), _ds.getShifts()]);
      final s = results[0] as ConfigSchoolSettings;
      final shifts = results[1] as List<ShiftConfig>;
      if (!mounted) return;
      setState(() {
        _absences.text = '${s.consecutiveAbsencesAlertThreshold}';
        _preceptorDays.text = '${s.preceptorTempAssignmentAlertDays}';
        _exceptionDays.text = '${s.scheduleExceptionAlertDays}';
        _lunchStart = s.lunchStart;
        _lunchStartFifth = s.lunchStartFifthModule;
        _lunchEnd = s.lunchEnd;
        _settingsSaved = false;
        _settingsError = null;
        _shifts = shifts;
        for (final sh in shifts) {
          (_shiftCtrls[sh.shift] ??= TextEditingController()).text = sh.label;
        }
      });
      await _cargarBreaks();
    } catch (_) {
      if (mounted) setState(() => _loadError = 'No se pudo cargar la configuración general.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarBreaks() async {
    setState(() => _breaksLoading = true);
    try {
      final b = await _ds.getShiftBreaks(_breakShift);
      if (mounted) setState(() => _breaks = b);
    } catch (_) {
      // silencioso: la lista queda como estaba
    } finally {
      if (mounted) setState(() => _breaksLoading = false);
    }
  }

  Future<void> _guardarSettings() async {
    final abs = int.tryParse(_absences.text.trim());
    final pd = int.tryParse(_preceptorDays.text.trim());
    final ed = int.tryParse(_exceptionDays.text.trim());
    if (abs == null || pd == null || ed == null) {
      setState(() => _settingsError = 'Los umbrales de alerta tienen que ser números enteros.');
      return;
    }
    setState(() {
      _savingSettings = true;
      _settingsError = null;
      _settingsSaved = false;
    });
    try {
      await _ds.actualizarConfigSchoolSettings(ConfigSchoolSettings(
        lunchStart: _lunchStart,
        lunchStartFifthModule: _lunchStartFifth,
        lunchEnd: _lunchEnd,
        consecutiveAbsencesAlertThreshold: abs,
        preceptorTempAssignmentAlertDays: pd,
        scheduleExceptionAlertDays: ed,
      ));
      if (!mounted) return;
      setState(() => _settingsSaved = true);
    } catch (e) {
      if (mounted) setState(() => _settingsError = e.toString());
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  bool _shiftDirty(ShiftConfig sh) => (_shiftCtrls[sh.shift]?.text ?? sh.label).trim() != sh.label;

  Future<void> _guardarShift(ShiftConfig sh) async {
    final label = _shiftCtrls[sh.shift]?.text.trim() ?? '';
    if (label.isEmpty) {
      _showError(context, 'El nombre del turno no puede quedar vacío.');
      return;
    }
    try {
      final updated = await _ds.renombrarShift(sh.shift, label);
      if (mounted) {
        setState(() {
          _shifts = [
            for (final s in _shifts) if (s.shift == sh.shift) updated else s,
          ];
        });
      }
    } catch (e) {
      if (mounted) _showError(context, e.toString());
    }
  }

  Future<void> _agregarBreak() async {
    final created = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _RecreoFormDialog(ds: _ds, shift: _breakShift),
    );
    if (created == true) _cargarBreaks();
  }

  Future<void> _quitarBreak(ShiftBreak b) async {
    final ok = await showAamConfirmDialog(
      context,
      titulo: 'Eliminar recreo',
      mensaje: '¿Eliminar "${b.label}" (${b.startTime}–${b.endTime}) del turno seleccionado?',
    );
    if (!ok) return;
    try {
      await _ds.eliminarShiftBreak(b.id);
      _cargarBreaks();
    } catch (e) {
      if (mounted) _showError(context, e.toString());
    }
  }

  String _shiftLabel(String shift) =>
      _shifts.firstWhere((s) => s.shift == shift, orElse: () => ShiftConfig(shift: shift, label: shift)).label;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    if (_loading) return const AAMLoadingScreen();
    if (_loadError != null) return AAMErrorWidget(message: _loadError!, onRetry: _cargar);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Alertas del panel ──
            _sectionCard(theme, title: 'Alertas del panel', subtitle: 'Cuándo la campana de notificaciones muestra cada aviso.', children: [
              _FieldGroup(
                label: 'Faltas consecutivas para alertar',
                hint: 'Avisa cuando un alumno acumula esta cantidad de faltas seguidas.',
                child: _numInput(_absences),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _FieldGroup(label: 'Aviso de reemplazo (días antes)', child: _numInput(_preceptorDays))),
                const SizedBox(width: 16),
                Expanded(child: _FieldGroup(label: 'Aviso de excepción de horario (días antes)', child: _numInput(_exceptionDays))),
              ]),
            ]),
            const SizedBox(height: 20),
            // ── Almuerzo ──
            _sectionCard(theme, title: 'Almuerzo', subtitle: 'No es un recreo. Si un curso de la mañana tiene 5º módulo ese día, el almuerzo arranca más tarde.', children: [
              Row(children: [
                Expanded(child: _FieldGroup(label: 'Inicio', child: _timeField(_lunchStart, (v) => setState(() {
                      _lunchStart = v;
                      _settingsSaved = false;
                    })))),
                const SizedBox(width: 16),
                Expanded(child: _FieldGroup(label: 'Inicio con 5º módulo', child: _timeField(_lunchStartFifth, (v) => setState(() {
                      _lunchStartFifth = v;
                      _settingsSaved = false;
                    })))),
                const SizedBox(width: 16),
                Expanded(child: _FieldGroup(label: 'Fin', child: _timeField(_lunchEnd, (v) => setState(() {
                      _lunchEnd = v;
                      _settingsSaved = false;
                    })))),
              ]),
            ]),
            const SizedBox(height: 16),
            if (_settingsError != null) ...[
              Text(_settingsError!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.danger)),
              const SizedBox(height: 12),
            ],
            if (_settingsSaved) ...[
              Row(children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AAMColors.success),
                const SizedBox(width: 8),
                Text('Cambios guardados.', style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.success)),
              ]),
              const SizedBox(height: 12),
            ],
            AAMButton(
              label: _savingSettings ? 'Guardando…' : 'Guardar alertas y almuerzo',
              icon: Icons.save_outlined,
              onPressed: _savingSettings ? null : _guardarSettings,
            ),
            const SizedBox(height: 28),
            // ── Turnos ──
            _sectionCard(theme, title: 'Turnos', subtitle: 'Solo el nombre. El horario de cada turno lo define cada curso en la sección Cursos.', children: [
              for (final sh in _shifts) ...[
                Row(children: [
                  Expanded(child: _FieldGroup(label: _defaultShiftName(sh.shift), child: _textInput(_shiftCtrls[sh.shift]!, 'Nombre del turno', onChanged: () => setState(() {})))),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: _RowActionBtn(
                      icon: Icons.check,
                      tooltip: 'Guardar nombre',
                      onTap: _shiftDirty(sh) ? () => _guardarShift(sh) : () {},
                    ),
                  ),
                ]),
                if (sh != _shifts.last) const SizedBox(height: 12),
              ],
            ]),
            const SizedBox(height: 20),
            // ── Recreos ──
            _sectionCard(theme, title: 'Recreos por turno', subtitle: 'Fijos para toda la escuela. Un horario de clase no puede caer sobre un recreo.', children: [
              SizedBox(
                width: 220,
                child: AAMLabeledDropdown<String>(
                  label: 'Turno',
                  value: _breakShift,
                  options: const ['morning', 'afternoon', 'evening'],
                  itemLabel: _shiftLabel,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _breakShift = v);
                    _cargarBreaks();
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (_breaksLoading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: AAMLoadingScreen())
              else if (_breaks.isEmpty)
                Text('Este turno no tiene recreos cargados.', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))
              else
                Column(children: [
                  for (final b in _breaks)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(child: Text(b.label,
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text))),
                        Text('${b.startTime} – ${b.endTime}', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
                        const SizedBox(width: 14),
                        _RowActionBtn(icon: Icons.delete_outline, tooltip: 'Eliminar', danger: true, onTap: () => _quitarBreak(b)),
                      ]),
                    ),
                ]),
              const SizedBox(height: 8),
              AAMButton(label: 'Agregar recreo', icon: Icons.add, outlined: true, onPressed: _agregarBreak),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _numInput(TextEditingController c) => _textInput(
        c,
        '0',
        keyboard: const TextInputType.numberWithOptions(),
        formatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: () => setState(() => _settingsSaved = false),
      );

  Widget _timeField(String value, ValueChanged<String> onPick) {
    final theme = AAMTheme();
    return GestureDetector(
      onTap: () async {
        final picked = await aamShowTimePicker(context, initialTime: _parseHHMM(value));
        if (picked != null) onPick(_fmtTOD(picked));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(value, style: GoogleFonts.dmSans(fontSize: 14, color: theme.text)),
          const Spacer(),
          Icon(Icons.schedule, size: 16, color: theme.textSec),
        ]),
      ),
    );
  }
}

String _defaultShiftName(String shift) => switch (shift) {
      'morning' => 'Mañana',
      'afternoon' => 'Tarde',
      'evening' => 'Vespertino',
      _ => shift,
    };

class _RecreoFormDialog extends StatefulWidget {
  const _RecreoFormDialog({required this.ds, required this.shift});
  final ApiDatasource ds;
  final String shift;

  @override
  State<_RecreoFormDialog> createState() => _RecreoFormDialogState();
}

class _RecreoFormDialogState extends State<_RecreoFormDialog> {
  final _label = TextEditingController();
  String _start = '09:30';
  String _end = '09:40';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_start.compareTo(_end) >= 0) {
      setState(() => _error = 'La hora de fin tiene que ser posterior a la de inicio.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ds.crearShiftBreak(
        shift: widget.shift,
        label: _label.text.trim(),
        startTime: _start,
        endTime: _end,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return AAMFormDialog(
      theme: theme,
      icon: Icons.free_breakfast_outlined,
      titulo: 'Nuevo recreo — ${_defaultShiftName(widget.shift)}',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      submitLabel: 'Agregar',
      children: [
        _FieldGroup(label: 'Nombre (opcional)', child: _textInput(_label, 'Ej: Recreo 1')),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _FieldGroup(label: 'Inicio', child: _dialogTimeField(context, _start, (v) => setState(() => _start = v)))),
          const SizedBox(width: 16),
          Expanded(child: _FieldGroup(label: 'Fin', child: _dialogTimeField(context, _end, (v) => setState(() => _end = v)))),
        ]),
      ],
    );
  }
}

Widget _dialogTimeField(BuildContext context, String value, ValueChanged<String> onPick) {
  final theme = AAMTheme();
  return GestureDetector(
    onTap: () async {
      final picked = await aamShowTimePicker(context, initialTime: _parseHHMM(value));
      if (picked != null) onPick(_fmtTOD(picked));
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text(value, style: GoogleFonts.dmSans(fontSize: 14, color: theme.text)),
        const Spacer(),
        Icon(Icons.schedule, size: 16, color: theme.textSec),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  Cursos (estructura académica)
// ═══════════════════════════════════════════════════════════════════════════

class _CursosSection extends StatefulWidget {
  const _CursosSection();

  @override
  State<_CursosSection> createState() => _CursosSectionState();
}

class _CursosSectionState extends State<_CursosSection> {
  final ApiDatasource _ds = ApiDatasource();

  bool _loading = true;
  String? _loadError;

  // Estado editable local.
  final _academicYear = TextEditingController();
  int _maxGradeYear = 7;
  // grade_year -> division_count
  final Map<int, int> _divCount = {};
  // (grade_year, division) -> workshop_group_count
  final Map<String, int> _wsCount = {};

  bool _saving = false;
  String? _saveError;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _academicYear.dispose();
    super.dispose();
  }

  String _k(int gy, int dv) => '$gy-$dv';

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final s = await _ds.getCoursesStructure();
      if (!mounted) return;
      setState(() {
        _academicYear.text = '${s.currentAcademicYear}';
        _maxGradeYear = s.maxGradeYear;
        _divCount.clear();
        _wsCount.clear();
        for (final y in s.years) {
          _divCount[y.gradeYear] = y.divisionCount;
          for (final d in y.divisions) {
            _wsCount[_k(y.gradeYear, d.division)] = d.workshopGroupCount;
          }
        }
        _saved = false;
        _saveError = null;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'No se pudo cargar la estructura de cursos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _divisionsOf(int gy) => (_divCount[gy] ?? 1).clamp(1, 20);
  int _wsOf(int gy, int dv) => _wsCount[_k(gy, dv)] ?? 0;

  void _setDivisions(int gy, int v) => setState(() {
        _divCount[gy] = v.clamp(1, 20);
        _saved = false;
      });

  void _setWs(int gy, int dv, int v) => setState(() {
        _wsCount[_k(gy, dv)] = v.clamp(0, 20);
        _saved = false;
      });

  Future<void> _guardar() async {
    final year = int.tryParse(_academicYear.text.trim());
    if (year == null || year < 2000 || year > 2100) {
      setState(() => _saveError = 'Ingresá un año lectivo válido.');
      return;
    }
    final years = <YearStructure>[];
    for (var gy = 1; gy <= _maxGradeYear; gy++) {
      final dc = _divisionsOf(gy);
      years.add(YearStructure(
        gradeYear: gy,
        divisionCount: dc,
        divisions: [
          for (var dv = 1; dv <= dc; dv++) DivisionStructure(division: dv, workshopGroupCount: _wsOf(gy, dv)),
        ],
      ));
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _saved = false;
    });
    try {
      await _ds.guardarCoursesStructure(CoursesStructure(
        currentAcademicYear: year,
        maxGradeYear: _maxGradeYear,
        years: years,
      ));
      if (!mounted) return;
      setState(() => _saved = true);
      _cargar();
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    if (_loading) return const AAMLoadingScreen();
    if (_loadError != null) return AAMErrorWidget(message: _loadError!, onRetry: _cargar);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionCard(theme, title: 'Estructura académica', subtitle: 'Define cuántos años, divisiones por año y grupos de taller por curso existen. Los cursos concretos se crean en la sección Cursos del menú, eligiendo entre estas opciones.', children: [
              Row(children: [
                Expanded(child: _FieldGroup(
                  label: 'Año lectivo actual',
                  child: _textInput(_academicYear, 'Ej: 2026', keyboard: TextInputType.number, onChanged: () => setState(() => _saved = false)),
                )),
                const SizedBox(width: 16),
                Expanded(child: _FieldGroup(
                  label: 'Cantidad de años (1–7)',
                  child: _stepper(
                    value: _maxGradeYear,
                    min: 1,
                    max: 7,
                    onChanged: (v) => setState(() {
                      _maxGradeYear = v;
                      _saved = false;
                    }),
                  ),
                )),
              ]),
            ]),
            const SizedBox(height: 20),
            _card(theme, Column(children: [
              for (var gy = 1; gy <= _maxGradeYear; gy++) _yearTile(theme, gy),
            ])),
            const SizedBox(height: 16),
            if (_saveError != null) ...[
              Text(_saveError!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.danger)),
              const SizedBox(height: 12),
            ],
            if (_saved) ...[
              Row(children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AAMColors.success),
                const SizedBox(width: 8),
                Text('Estructura guardada.', style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.success)),
              ]),
              const SizedBox(height: 12),
            ],
            AAMButton(
              label: _saving ? 'Guardando…' : 'Guardar estructura',
              icon: Icons.save_outlined,
              onPressed: _saving ? null : _guardar,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _yearTile(AAMTheme theme, int gy) {
    final dc = _divisionsOf(gy);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(children: [
          Text('${_ordinal(gy)} año', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text)),
          const SizedBox(width: 12),
          Text('$dc ${dc == 1 ? "división" : "divisiones"}', style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
        ]),
        children: [
          Row(children: [
            Text('Divisiones', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
            const SizedBox(width: 12),
            _stepper(value: dc, min: 1, max: 20, onChanged: (v) => _setDivisions(gy, v)),
          ]),
          const SizedBox(height: 12),
          for (var dv = 1; dv <= dc; dv++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(child: Text('${_ordinal(gy)} ${_divOrdinal(dv)}',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text))),
                  Text('Grupos de taller', style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
                  const SizedBox(width: 12),
                  _stepper(value: _wsOf(gy, dv), min: 0, max: 20, onChanged: (v) => _setWs(gy, dv, v)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepper({required int value, required int min, required int max, required ValueChanged<int> onChanged}) {
    final theme = AAMTheme();
    Widget btn(IconData i, VoidCallback? onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: theme.borderCol),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(i, size: 16, color: onTap == null ? theme.borderCol : theme.textSec),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
      Container(
        width: 40,
        alignment: Alignment.center,
        child: Text('$value', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text)),
      ),
      btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Dispositivos
// ═══════════════════════════════════════════════════════════════════════════

class _DispositivosSection extends StatefulWidget {
  const _DispositivosSection();

  @override
  State<_DispositivosSection> createState() => _DispositivosSectionState();
}

class _DispositivosSectionState extends State<_DispositivosSection> {
  final ApiDatasource _ds = ApiDatasource();

  List<EntryPoint>? _entryPoints;
  List<ReaderDevice>? _devices;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = _entryPoints == null;
      _error = null;
    });
    try {
      final results = await Future.wait([_ds.getEntryPoints(), _ds.getConfigDevices()]);
      if (!mounted) return;
      setState(() {
        _entryPoints = results[0] as List<EntryPoint>;
        _devices = results[1] as List<ReaderDevice>;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los dispositivos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _nuevoEntryPoint() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _EntryPointFormDialog(ds: _ds),
    );
    if (ok == true) _cargar();
  }

  Future<void> _editarEntryPoint(EntryPoint e) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _EntryPointFormDialog(ds: _ds, entryPoint: e),
    );
    if (ok == true) _cargar();
  }

  Future<void> _eliminarEntryPoint(EntryPoint e) async {
    final ok = await showAamConfirmDialog(
      context,
      titulo: 'Eliminar punto de acceso',
      mensaje: '¿Eliminar "${e.name}"? Si tiene dispositivos asociados, el sistema no va a permitir borrarlo.',
    );
    if (!ok) return;
    try {
      await _ds.eliminarEntryPoint(e.id);
      _cargar();
    } catch (err) {
      if (mounted) _showError(context, err.toString());
    }
  }

  Future<void> _nuevoDispositivo() async {
    final eps = _entryPoints ?? [];
    if (eps.isEmpty) {
      _showError(context, 'Primero creá un punto de acceso: cada dispositivo tiene que pertenecer a uno.');
      return;
    }
    final created = await showDialog<CreatedDevice>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _DispositivoFormDialog(ds: _ds, entryPoints: eps),
    );
    if (created != null && mounted) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
        builder: (_) => _ApiKeyRevealDialog(created: created),
      );
      _cargar();
    }
  }

  Future<void> _revocar(ReaderDevice d) async {
    final ok = await showAamConfirmDialog(
      context,
      titulo: 'Revocar dispositivo',
      mensaje: '¿Revocar "${d.name}"? Su API key deja de funcionar al instante y no se puede reactivar.',
    );
    if (!ok) return;
    try {
      await _ds.revocarConfigDevice(d.id);
      _cargar();
    } catch (e) {
      if (mounted) _showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    if (_loading && _entryPoints == null) return const AAMLoadingScreen();
    if (_error != null && _entryPoints == null) return AAMErrorWidget(message: _error!, onRetry: _cargar);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _blockHeader(theme,
            titulo: 'Puntos de acceso',
            subtitulo: 'Dónde están instalados los lectores (una puerta, un portón).',
            actionLabel: 'Nuevo punto de acceso',
            onAction: _nuevoEntryPoint),
        const SizedBox(height: 16),
        _entryPointsTabla(theme),
        const SizedBox(height: 36),
        _blockHeader(theme,
            titulo: 'Dispositivos',
            subtitulo: 'Lectores ESP32 registrados. La API key se muestra una sola vez, al registrarlo.',
            actionLabel: 'Nuevo dispositivo',
            onAction: _nuevoDispositivo),
        const SizedBox(height: 16),
        _devicesTabla(theme),
      ]),
    );
  }

  Widget _entryPointsTabla(AAMTheme theme) {
    final items = _entryPoints ?? [];
    if (items.isEmpty) {
      return _card(theme, _EmptyState(
        icon: Icons.meeting_room_outlined,
        message: 'No hay puntos de acceso',
        actionLabel: 'Crear el primero',
        onAction: _nuevoEntryPoint,
        compact: true,
      ));
    }
    return _card(theme, Column(mainAxisSize: MainAxisSize.min, children: [
      const AAMTableHeader(columns: [('Nombre', 3), ('Ubicación', 4), ('', 2)]),
      for (final e in items)
        _HoverRow(theme: theme, cells: [
          (3, Text(e.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text))),
          (4, Text(e.location ?? '—', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))),
          (2, Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _RowActionBtn(icon: Icons.edit_outlined, tooltip: 'Editar', onTap: () => _editarEntryPoint(e)),
            const SizedBox(width: 14),
            _RowActionBtn(icon: Icons.delete_outline, tooltip: 'Eliminar', danger: true, onTap: () => _eliminarEntryPoint(e)),
          ])),
        ]),
    ]));
  }

  Widget _devicesTabla(AAMTheme theme) {
    final items = _devices ?? [];
    if (items.isEmpty) {
      return _card(theme, _EmptyState(
        icon: Icons.nfc,
        message: 'No hay dispositivos registrados',
        actionLabel: 'Registrar el primero',
        onAction: _nuevoDispositivo,
        compact: true,
      ));
    }
    return _card(theme, Column(mainAxisSize: MainAxisSize.min, children: [
      const AAMTableHeader(columns: [('Nombre', 3), ('Punto de acceso', 3), ('Estado', 2), ('Alta', 2), ('', 2)]),
      for (final d in items)
        _HoverRow(theme: theme, cells: [
          (3, Text(d.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text))),
          (3, Text(d.entryPointName, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))),
          (2, d.isRevoked
              ? const AAMBadge(label: 'Revocado', color: AAMColors.danger)
              : const AAMBadge(label: 'Activo', color: AAMColors.success)),
          (2, Text(_fecha(d.createdAt), style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec))),
          (2, Align(
            alignment: Alignment.centerRight,
            child: d.isRevoked
                ? Text('—', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))
                : _RowActionBtn(icon: Icons.block_outlined, tooltip: 'Revocar', danger: true, onTap: () => _revocar(d)),
          )),
        ]),
    ]));
  }
}

class _EntryPointFormDialog extends StatefulWidget {
  const _EntryPointFormDialog({required this.ds, this.entryPoint});
  final ApiDatasource ds;
  final EntryPoint? entryPoint;

  @override
  State<_EntryPointFormDialog> createState() => _EntryPointFormDialogState();
}

class _EntryPointFormDialogState extends State<_EntryPointFormDialog> {
  late final TextEditingController _nombre;
  late final TextEditingController _ubicacion;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.entryPoint != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.entryPoint?.name ?? '');
    _ubicacion = TextEditingController(text: widget.entryPoint?.location ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ubicacion.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá el nombre del punto de acceso.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.ds.actualizarEntryPoint(id: widget.entryPoint!.id, name: _nombre.text.trim(), location: _ubicacion.text.trim());
      } else {
        await widget.ds.crearEntryPoint(name: _nombre.text.trim(), location: _ubicacion.text.trim());
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return AAMFormDialog(
      theme: theme,
      icon: _isEdit ? Icons.edit_outlined : Icons.meeting_room_outlined,
      titulo: _isEdit ? 'Editar punto de acceso' : 'Nuevo punto de acceso',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      submitLabel: _isEdit ? 'Guardar' : 'Crear',
      children: [
        _FieldGroup(label: 'Nombre', child: _textInput(_nombre, 'Ej: Puerta principal')),
        const SizedBox(height: 16),
        _FieldGroup(label: 'Ubicación (opcional)', child: _textInput(_ubicacion, 'Ej: Planta baja')),
      ],
    );
  }
}

class _DispositivoFormDialog extends StatefulWidget {
  const _DispositivoFormDialog({required this.ds, required this.entryPoints});
  final ApiDatasource ds;
  final List<EntryPoint> entryPoints;

  @override
  State<_DispositivoFormDialog> createState() => _DispositivoFormDialogState();
}

class _DispositivoFormDialogState extends State<_DispositivoFormDialog> {
  final _nombre = TextEditingController();
  EntryPoint? _entryPoint;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.entryPoints.length == 1) _entryPoint = widget.entryPoints.first;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_entryPoint == null) {
      setState(() => _error = 'Elegí el punto de acceso.');
      return;
    }
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá el nombre del dispositivo.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await widget.ds.crearConfigDevice(entryPointId: _entryPoint!.id, name: _nombre.text.trim());
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return AAMFormDialog(
      theme: theme,
      icon: Icons.nfc,
      titulo: 'Nuevo dispositivo',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      submitLabel: 'Registrar',
      children: [
        _FieldGroup(label: 'Nombre', child: _textInput(_nombre, 'Ej: ESP32-AULA-12')),
        const SizedBox(height: 16),
        AAMLabeledDropdown<EntryPoint>(
          label: 'Punto de acceso',
          value: _entryPoint,
          options: widget.entryPoints,
          itemLabel: (e) => e.name,
          hint: 'Punto de acceso',
          onChanged: (v) => setState(() => _entryPoint = v),
        ),
        const SizedBox(height: 6),
        Text('La API key se genera en el servidor y se muestra una sola vez al terminar.',
            style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
      ],
    );
  }
}

class _ApiKeyRevealDialog extends StatelessWidget {
  const _ApiKeyRevealDialog({required this.created});
  final CreatedDevice created;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(20), boxShadow: [
          BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8)),
        ]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AAMColors.success, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check, size: 18, color: AAMColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Dispositivo registrado',
                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text))),
          ]),
          const SizedBox(height: 18),
          Text('${created.device.name} · ${created.device.entryPointName}',
              style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
          const SizedBox(height: 16),
          Text('API key — copiala ahora, no se puede volver a ver:',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surfaceCol,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AAMColors.accent.withAlpha((0.4 * 255).round())),
            ),
            child: SelectableText(created.apiKey,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AAMColors.primary)),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: AAMButton(
              label: 'Copiar',
              icon: Icons.copy_outlined,
              outlined: true,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: created.apiKey));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key copiada'), duration: Duration(seconds: 2)),
                );
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: AAMButton(label: 'Listo', onPressed: () => Navigator.of(context).pop())),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Helpers compartidos
// ═══════════════════════════════════════════════════════════════════════════

Widget _blockHeader(
  AAMTheme theme, {
  required String titulo,
  required String subtitulo,
  required String actionLabel,
  required VoidCallback onAction,
}) {
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
        const SizedBox(height: 4),
        Text(subtitulo, style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
      ]),
    ),
    const SizedBox(width: 16),
    AAMButton(label: actionLabel, icon: Icons.add, onPressed: onAction),
  ]);
}

Widget _sectionCard(
  AAMTheme theme, {
  required String title,
  required String subtitle,
  required List<Widget> children,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: theme.card,
      border: Border.all(color: theme.borderCol),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text)),
      const SizedBox(height: 4),
      Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
      const SizedBox(height: 20),
      ...children,
    ]),
  );
}

Widget _card(AAMTheme theme, Widget child) {
  return Container(
    decoration: BoxDecoration(
      color: theme.card,
      border: Border.all(color: theme.borderCol),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.theme, required this.cells});
  final AAMTheme theme;
  final List<(int flex, Widget child)> cells;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _hovered ? widget.theme.surfaceCol : widget.theme.card,
          border: Border(bottom: BorderSide(color: widget.theme.borderCol, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [for (final c in widget.cells) Expanded(flex: c.$1, child: c.$2)],
        ),
      ),
    );
  }
}

class _RowActionBtn extends StatefulWidget {
  const _RowActionBtn({required this.icon, required this.tooltip, required this.onTap, this.danger = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_RowActionBtn> createState() => _RowActionBtnState();
}

class _RowActionBtnState extends State<_RowActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.danger ? AAMColors.danger : AAMColors.accent;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Icon(widget.icon, size: 18, color: _hovered ? hoverColor : AAMColors.textSec),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: theme.borderCol),
      const SizedBox(height: 12),
      Text(message, style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 12),
        AAMButton(label: actionLabel!, onPressed: onAction),
      ],
    ]);
    return compact
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 36), child: Center(child: content))
        : Center(child: content);
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label, required this.child, this.hint});
  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
      const SizedBox(height: 6),
      child,
      if (hint != null) ...[
        const SizedBox(height: 6),
        Text(hint!, style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
      ],
    ]);
  }
}

Widget _textInput(
  TextEditingController controller,
  String hint, {
  TextInputType? keyboard,
  List<TextInputFormatter>? formatters,
  VoidCallback? onChanged,
}) {
  final theme = AAMTheme();
  return Container(
    decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      onChanged: onChanged == null ? null : (_) => onChanged(),
      style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
  );
}

void _showError(BuildContext context, String mensaje) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
    builder: (_) => _ErrorModal(mensaje: mensaje),
  );
}

class _ErrorModal extends StatelessWidget {
  const _ErrorModal({required this.mensaje});
  final String mensaje;

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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.error_outline, size: 20, color: AAMColors.danger),
                const SizedBox(width: 10),
                Expanded(child: Text('No se pudo completar la acción',
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text))),
              ]),
              const SizedBox(height: 10),
              Text(mensaje, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Entendido',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

String _fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

TimeOfDay _parseHHMM(String s) {
  final p = s.split(':');
  return TimeOfDay(hour: int.tryParse(p.first) ?? 0, minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
}

String _fmtTOD(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _gradeOrdinals = ['', '1er', '2do', '3er', '4to', '5to', '6to', '7mo'];
String _ordinal(int y) => (y >= 1 && y <= 7) ? _gradeOrdinals[y] : '$y°';

const _divOrdinals = ['', '1ra', '2da', '3ra', '4ta', '5ta', '6ta', '7ma', '8va', '9na', '10ma'];
String _divOrdinal(int d) => (d >= 1 && d < _divOrdinals.length) ? _divOrdinals[d] : '$d°';
