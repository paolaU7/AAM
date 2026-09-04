import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/academic.dart';
import '../../domain/entities/course.dart' show gradeYearOrdinal;
import '../../domain/entities/specialty.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../widgets/aam_design_system.dart';
import '../widgets/auto_refresh_mixin.dart';

/// Catálogo global de materias (nombre + tipo fijo) y, por cada una, en qué
/// año(s) de cursada (+especialidad si corresponde) se puede dictar. Esto es
/// lo que filtra el desplegable de materias al armar el horario de un curso
/// (ver `cursos_screen.dart`, `_AsignarMateriaForm` y `_NuevoPeriodoForm`).
class MateriasScreen extends StatefulWidget {
  const MateriasScreen({super.key});

  @override
  State<MateriasScreen> createState() => _MateriasScreenState();
}

class _MateriasScreenState extends State<MateriasScreen> with AutoRefreshMixin<MateriasScreen> {
  final ApiDatasource _ds = ApiDatasource();

  List<Subject>? _materias;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    startAutoRefresh();
  }

  @override
  void onAutoRefresh() => _cargar(silent: true);

  Future<void> _cargar({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await _ds.getSubjects();
      if (mounted) setState(() { _materias = data; _error = null; });
    } catch (_) {
      if (mounted && !silent) setState(() => _error = 'Error al cargar materias');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _abrirNuevaMateria() async {
    final creada = await showDialog<Subject>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevaMateriaForm(ds: _ds),
    );
    if (creada != null) _cargar();
  }

  Future<void> _gestionarAplicabilidad(Subject s) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _AplicabilidadModal(ds: _ds, subject: s),
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
    return Column(children: [
      AAMTopbar(
        title: 'Materias',
        actions: [
          AAMButton(label: 'Nueva materia', icon: Icons.add, onPressed: _abrirNuevaMateria),
        ],
      ),
      Expanded(
        child: _loading && _materias == null
            ? const AAMLoadingScreen()
            : _error != null && _materias == null
                ? AAMErrorWidget(message: _error!, onRetry: _cargar)
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: _buildTabla(_materias ?? [], theme),
                  ),
      ),
    ]);
  }

  Widget _buildTabla(List<Subject> materias, AAMTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const AAMTableHeader(columns: [
          ('Nombre', 4),
          ('Tipo', 2),
          ('', 2),
        ]),
        Expanded(
          child: materias.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 40, color: theme.borderCol),
                    const SizedBox(height: 12),
                    Text('No hay materias cargadas', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
                    const SizedBox(height: 8),
                    AAMButton(label: 'Crear primera materia', onPressed: _abrirNuevaMateria),
                  ],
                ))
              : ListView.builder(
                  itemCount: materias.length,
                  itemBuilder: (ctx, i) => _MateriaRow(
                    materia: materias[i],
                    theme: theme,
                    onGestionar: () => _gestionarAplicabilidad(materias[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _MateriaRow extends StatefulWidget {
  const _MateriaRow({required this.materia, required this.theme, required this.onGestionar});
  final Subject materia;
  final AAMTheme theme;
  final VoidCallback onGestionar;

  @override
  State<_MateriaRow> createState() => _MateriaRowState();
}

class _MateriaRowState extends State<_MateriaRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.materia;
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
        child: Row(children: [
          Expanded(flex: 4, child: Text(m.name,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text))),
          Expanded(flex: 2, child: AAMBadge(
            label: subjectTypeLabel(m.subjectType),
            color: m.subjectType == SubjectType.workshop ? AAMColors.teal : AAMColors.primary,
          )),
          Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _RowActionBtn(icon: Icons.tune, tooltip: 'Gestionar aplicabilidad', onTap: widget.onGestionar),
          ])),
        ]),
      ),
    );
  }
}

class _RowActionBtn extends StatefulWidget {
  const _RowActionBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_RowActionBtn> createState() => _RowActionBtnState();
}

class _RowActionBtnState extends State<_RowActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Icon(widget.icon, size: 18, color: _hovered ? AAMColors.accent : AAMColors.textSec),
        ),
      ),
    );
  }
}

// ─── Nueva materia ──────────────────────────────────────────────────────────
class _NuevaMateriaForm extends StatefulWidget {
  const _NuevaMateriaForm({required this.ds});
  final ApiDatasource ds;

  @override
  State<_NuevaMateriaForm> createState() => _NuevaMateriaFormState();
}

class _NuevaMateriaFormState extends State<_NuevaMateriaForm> {
  final _nombreCtrl = TextEditingController();
  SubjectType _tipo = SubjectType.curricular;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá el nombre de la materia.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final creada = await widget.ds.crearSubject(name: _nombreCtrl.text.trim(), subjectType: _tipo);
      if (mounted) Navigator.of(context).pop(creada);
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
      icon: Icons.menu_book_outlined,
      titulo: 'Nueva materia',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      submitLabel: 'Crear materia',
      children: [
        _FieldGroup(label: 'Nombre', child: _textInput(_nombreCtrl, 'Ej: Matemática')),
        const SizedBox(height: 16),
        AAMLabeledDropdown<SubjectType>(
          label: 'Tipo',
          value: _tipo,
          options: SubjectType.values,
          itemLabel: subjectTypeLabel,
          onChanged: (v) => setState(() => _tipo = v ?? _tipo),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AAMColors.warning.withAlpha((0.12 * 255).round()),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AAMColors.warning.withAlpha((0.3 * 255).round())),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 15, color: AAMColors.warning),
            const SizedBox(width: 8),
            Expanded(child: Text('El tipo no se puede cambiar después de creada la materia.',
                style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec))),
          ]),
        ),
      ],
    );
  }
}

// ─── Aplicabilidad (año de cursada + especialidad) ─────────────────────────
class _AplicabilidadModal extends StatefulWidget {
  const _AplicabilidadModal({required this.ds, required this.subject});
  final ApiDatasource ds;
  final Subject subject;

  @override
  State<_AplicabilidadModal> createState() => _AplicabilidadModalState();
}

class _AplicabilidadModalState extends State<_AplicabilidadModal> {
  List<SubjectApplicability> _items = [];
  List<Specialty> _especialidades = [];
  SchoolSettings? _settings;
  bool _catalogosLoading = true;
  bool _submitting = false;
  String? _error;

  int? _gradeYear;
  Specialty? _especialidadSel;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _catalogosLoading = true);
    try {
      final results = await Future.wait([
        widget.ds.getSubjectApplicability(widget.subject.id),
        widget.ds.getSpecialties(),
        widget.ds.getSchoolSettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<SubjectApplicability>;
        _especialidades = results[1] as List<Specialty>;
        _settings = results[2] as SchoolSettings;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la aplicabilidad.');
    } finally {
      if (mounted) setState(() => _catalogosLoading = false);
    }
  }

  // Mismo patrón que en el alta de curso (`_CursoFormState`): 1ro-3ro siempre
  // Ciclo Básico (automático), 4to en adelante siempre una especialidad real.
  bool get _esCicloBasico => _gradeYear != null && _gradeYear! <= 3;

  Specialty? get _cicloBasico {
    try {
      return _especialidades.firstWhere((s) => s.isBasicCycle);
    } catch (_) {
      return null;
    }
  }

  List<Specialty> get _especialidadesElegibles => _especialidades.where((s) => !s.isBasicCycle).toList();

  void _onGradeYearChanged(int? v) {
    setState(() {
      _gradeYear = v;
      if (_esCicloBasico) {
        _especialidadSel = _cicloBasico;
      } else if (_especialidadSel?.isBasicCycle == true) {
        _especialidadSel = null;
      }
    });
  }

  Future<void> _agregar() async {
    if (_gradeYear == null) {
      setState(() => _error = 'Seleccioná el año de cursada.');
      return;
    }
    final especialidad = _esCicloBasico ? _cicloBasico : _especialidadSel;
    if (especialidad == null) {
      setState(() => _error = _esCicloBasico
          ? 'No se encontró la especialidad "Ciclo Básico" en el catálogo.'
          : 'Seleccioná la especialidad.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.ds.agregarSubjectApplicability(
        subjectId: widget.subject.id, gradeYear: _gradeYear!, specialtyId: especialidad.id,
      );
      if (mounted) setState(() { _gradeYear = null; _especialidadSel = null; });
      await _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _quitar(SubjectApplicability a) async {
    final ok = await showAamConfirmDialog(context,
        titulo: 'Quitar aplicabilidad',
        mensaje: '¿Quitar "${gradeYearOrdinal(a.gradeYear)} — ${a.specialtyName}"? '
            'Si algún curso ya tiene esta materia asignada en ese contexto, va a rechazarse.');
    if (!ok) return;
    try {
      await widget.ds.quitarSubjectApplicability(widget.subject.id, a.id);
      _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: _catalogosLoading
            ? const Padding(padding: EdgeInsets.all(20), child: AAMLoadingScreen())
            : SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AAMColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.tune, size: 18, color: AAMColors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Aplicabilidad — ${widget.subject.name}',
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text))),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.close, size: 16, color: theme.textSec),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  if (_items.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AAMColors.warning.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Sin años/especialidades habilitados todavía — la materia no va a poder asignarse a ningún curso hasta que agregues al menos uno.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
                    )
                  else
                    ..._items.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              Expanded(child: Text('${gradeYearOrdinal(a.gradeYear)} — ${a.specialtyName}',
                                  style: GoogleFonts.dmSans(fontSize: 13, color: theme.text))),
                              GestureDetector(
                                onTap: () => _quitar(a),
                                child: const Icon(Icons.close, size: 16, color: AAMColors.danger),
                              ),
                            ]),
                          ),
                        )),
                  const SizedBox(height: 12),
                  Divider(color: theme.borderCol),
                  const SizedBox(height: 12),
                  Text('Agregar', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: AAMLabeledDropdown<int>(
                      label: 'Año de cursada',
                      value: _gradeYear,
                      options: List.generate(_settings?.maxGradeYear ?? 7, (i) => i + 1),
                      hint: 'Año de cursada',
                      itemLabel: gradeYearOrdinal,
                      onChanged: _onGradeYearChanged,
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _esCicloBasico
                          ? _FieldGroup(label: 'Especialidad', child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(10)),
                              child: Text('Ciclo Básico (automático)', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
                            ))
                          : AAMLabeledDropdown<Specialty>(
                              label: 'Especialidad',
                              value: _especialidadSel,
                              options: _especialidadesElegibles,
                              hint: _gradeYear == null ? 'Elegí el año primero' : 'Especialidad',
                              itemLabel: (s) => s.name,
                              onChanged: _gradeYear == null ? null : (v) => setState(() => _especialidadSel = v),
                            ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (_error != null) ...[
                    Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger)),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Expanded(child: AAMButton(
                      label: _submitting ? 'Agregando…' : 'Agregar',
                      icon: Icons.add,
                      onPressed: _submitting ? null : _agregar,
                    )),
                  ]),
                ]),
              ),
      ),
    );
  }
}

Widget _textInput(TextEditingController controller, String hint, {TextInputType? keyboard}) {
  final theme = AAMTheme();
  return Container(
    decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
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

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
      const SizedBox(height: 6),
      child,
    ]);
  }
}
