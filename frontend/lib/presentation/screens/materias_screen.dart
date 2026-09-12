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

  // Catálogos para los selects de filtro — se cargan una sola vez, no en
  // cada refresco periódico de materias.
  List<Specialty> _especialidades = [];
  int _maxGradeYear = 7;

  // Filtros, combinables con AND.
  String _searchQuery = '';
  SubjectType? _filterTipo;
  int? _filterAnio;
  Specialty? _filterEspecialidad;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarFiltros();
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

  Future<void> _cargarFiltros() async {
    try {
      final results = await Future.wait([_ds.getSpecialties(), _ds.getSchoolSettings()]);
      if (!mounted) return;
      setState(() {
        _especialidades = results[0] as List<Specialty>;
        _maxGradeYear = (results[1] as SchoolSettings).maxGradeYear;
      });
    } catch (_) {
      // Los selects quedan con las opciones por defecto — no bloquea la tabla.
    }
  }

  bool get _hayFiltrosActivos =>
      _searchQuery.isNotEmpty || _filterTipo != null || _filterAnio != null || _filterEspecialidad != null;

  void _limpiarFiltros() {
    setState(() {
      _searchQuery = '';
      _filterTipo = null;
      _filterAnio = null;
      _filterEspecialidad = null;
    });
  }

  List<Subject> _applyFilters(List<Subject> materias) {
    return materias.where((m) {
      final matchSearch = _searchQuery.isEmpty ||
          m.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchTipo = _filterTipo == null || m.subjectType == _filterTipo;
      final matchAnio = _filterAnio == null ||
          m.applicability.any((a) => a.gradeYear == _filterAnio);
      final matchEspecialidad = _filterEspecialidad == null ||
          m.applicability.any((a) => a.specialtyId == _filterEspecialidad!.id);
      return matchSearch && matchTipo && matchAnio && matchEspecialidad;
    }).toList();
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
    // La aplicabilidad puede haber cambiado — los filtros de año/especialidad
    // la necesitan al día, no solo en el próximo refresco periódico.
    _cargar();
  }

  Future<void> _editarMateria(Subject s) async {
    final editado = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _EditarMateriaForm(ds: _ds, subject: s),
    );
    if (editado == true) _cargar();
  }

  Future<void> _editarShortCode(Subject s) async {
    final editado = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _ShortCodeForm(ds: _ds, subject: s),
    );
    if (editado == true) _cargar();
  }

  Future<void> _toggleActivo(Subject s) async {
    try {
      await _ds.toggleSubjectActive(s.id);
      _cargar();
    } catch (_) {
      // El estado no cambió — no hay nada más que hacer acá, se puede
      // reintentar con el mismo botón.
    }
  }

  /// Borrado físico — el botón que llama a esto solo se muestra cuando
  /// `!materia.isActive` (ver `_MateriaRow`), pero el backend igual vuelve a
  /// validarlo: no hay que confiar solo en que el frontend lo oculte.
  Future<void> _eliminarMateria(Subject s) async {
    final ok = await showAamConfirmDialog(
      context,
      titulo: 'Eliminar materia',
      mensaje: '¿Eliminar "${s.name}" definitivamente? Esta acción no se puede deshacer. '
          'Si tiene cursos o profesores asociados, no va a poder eliminarse.',
    );
    if (!ok) return;
    try {
      await _ds.eliminarSubject(s.id);
      _cargar();
    } catch (e) {
      if (mounted) _showError(context, e.toString());
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
    final todas = _materias ?? [];
    final materias = _applyFilters(todas);
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
                    child: Column(children: [
                      _buildFiltros(theme, todas.length, materias.length),
                      const SizedBox(height: 20),
                      Expanded(child: _buildTabla(materias, theme)),
                    ]),
                  ),
      ),
    ]);
  }

  Widget _buildFiltros(AAMTheme theme, int total, int filtrado) {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: _kFiltroAltura,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.card,
              border: Border.all(color: theme.borderCol),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: 'Buscar por nombre...',
                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec),
                prefixIcon: Icon(Icons.search, size: 18, color: theme.textSec),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      _filterBox(theme, AAMDropdown<SubjectType?>(
        value: _filterTipo,
        options: <SubjectType?>[null, ...SubjectType.values],
        itemLabel: (t) => t == null ? 'Tipo: todos' : subjectTypeLabel(t),
        fontSize: 13,
        isDense: true,
        onChanged: (v) => setState(() => _filterTipo = v),
      )),
      const SizedBox(width: 12),
      _filterBox(theme, AAMDropdown<int?>(
        value: _filterAnio,
        options: <int?>[null, ...List.generate(_maxGradeYear, (i) => i + 1)],
        itemLabel: (a) => a == null ? 'Año: todos' : gradeYearOrdinal(a),
        fontSize: 13,
        isDense: true,
        onChanged: (v) => setState(() => _filterAnio = v),
      )),
      const SizedBox(width: 12),
      _filterBox(theme, AAMDropdown<Specialty?>(
        value: _filterEspecialidad,
        options: <Specialty?>[null, ..._especialidades],
        itemLabel: (s) => s == null ? 'Especialidad: todas' : s.name,
        fontSize: 13,
        isDense: true,
        onChanged: (v) => setState(() => _filterEspecialidad = v),
      )),
      const SizedBox(width: 12),
      _buildLimpiarFiltros(theme),
      const SizedBox(width: 12),
      Text('$filtrado de $total materias', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
    ]);
  }

  Widget _filterBox(AAMTheme theme, Widget child) {
    return Container(
      height: _kFiltroAltura,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _buildLimpiarFiltros(AAMTheme theme) {
    final activo = _hayFiltrosActivos;
    return GestureDetector(
      onTap: activo ? _limpiarFiltros : null,
      child: MouseRegion(
        cursor: activo ? SystemMouseCursors.click : MouseCursor.defer,
        child: Opacity(
          opacity: activo ? 1 : 0.4,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.filter_alt_off_outlined, size: 16, color: AAMColors.danger),
            const SizedBox(width: 6),
            Text('Borrar filtros', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AAMColors.danger)),
          ]),
        ),
      ),
    );
  }

  Widget _buildTabla(List<Subject> materias, AAMTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const AAMTableHeader(
          columns: [
            ('Identificador', 2),
            ('Nombre', 3),
            ('Tipo', 2),
            ('Años asignados', 4),
            ('Acciones', 4),
          ],
        ),
        Expanded(
          child: materias.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 40, color: theme.borderCol),
                    const SizedBox(height: 12),
                    Text(
                      (_materias ?? []).isEmpty ? 'No hay materias cargadas' : 'Ninguna materia coincide con los filtros',
                      style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec),
                    ),
                    const SizedBox(height: 8),
                    if ((_materias ?? []).isEmpty)
                      AAMButton(label: 'Crear primera materia', onPressed: _abrirNuevaMateria)
                    else
                      AAMButton(label: 'Borrar filtros', outlined: true, onPressed: _limpiarFiltros),
                  ],
                ))
              : ListView.builder(
                  itemCount: materias.length,
                  itemBuilder: (ctx, i) => _MateriaRow(
                    materia: materias[i],
                    theme: theme,
                    onGestionar: () => _gestionarAplicabilidad(materias[i]),
                    onEditarMateria: () => _editarMateria(materias[i]),
                    onEditarShortCode: () => _editarShortCode(materias[i]),
                    onToggleActivo: () => _toggleActivo(materias[i]),
                    onEliminar: () => _eliminarMateria(materias[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// Altura común del buscador y de cada caja de filtro (ver students_screen.dart
// para el mismo patrón); los dropdowns van con isDense para entrar en 40.
const double _kFiltroAltura = 40;

/// "1ro, 3ro, 5to (E)": todos los pares (año, especialidad) de la
/// aplicabilidad de la materia, ordenados por año. 1ro a 3ro es siempre
/// "Ciclo Básico" (implícito), así que no lleva paréntesis; de 4to en
/// adelante sí, con la inicial de la especialidad (E = Electrónica,
/// P = Programación, C = Construcciones...). Un mismo año puede repetirse
/// con especialidades distintas (ej. "4to (E), 4to (P)") — se muestran ambas.
String _aniosAsignadosLabel(Subject m) {
  if (m.applicability.isEmpty) return 'Sin años asignados';
  final items = [...m.applicability]..sort((a, b) => a.gradeYear.compareTo(b.gradeYear));
  return items.map((a) {
    final anio = gradeYearOrdinal(a.gradeYear);
    if (a.gradeYear <= 3) return anio;
    final inicial = a.specialtyName.isNotEmpty ? a.specialtyName[0].toUpperCase() : '';
    return '$anio ($inicial)';
  }).join(', ');
}

class _MateriaRow extends StatefulWidget {
  const _MateriaRow({
    required this.materia,
    required this.theme,
    required this.onGestionar,
    required this.onEditarMateria,
    required this.onEditarShortCode,
    required this.onToggleActivo,
    required this.onEliminar,
  });
  final Subject materia;
  final AAMTheme theme;
  final VoidCallback onGestionar;
  final VoidCallback onEditarMateria;
  final VoidCallback onEditarShortCode;
  final VoidCallback onToggleActivo;
  final VoidCallback onEliminar;

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
      child: Opacity(
        // Materias dadas de baja se muestran atenuadas, no ocultas — mismo
        // criterio que el resto de los toggles de la app (ver Alumnos).
        opacity: m.isActive ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? widget.theme.surfaceCol : widget.theme.card,
            border: Border(bottom: BorderSide(color: widget.theme.borderCol, width: 1)),
          ),
          child: Row(children: [
            Expanded(flex: 2, child: m.shortCode.isEmpty
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.center,
                    child: Tooltip(
                      message: 'Identificador corto de la materia (se usa para diferenciarla rápido, '
                          'p.ej. en horarios). Se genera solo a partir del nombre y los años asignados'
                          '${m.shortCodeAuto ? '' : ' — este fue editado a mano'}.',
                      waitDuration: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.theme.surfaceCol,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: widget.theme.borderCol),
                        ),
                        child: Text(m.shortCode,
                            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: widget.theme.textSec)),
                      ),
                    ),
                  )),
            Expanded(flex: 3, child: Text(m.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text))),
            // AAMColors.primary es el texto navy de modo claro (theme.text ahí
            // apunta al mismo valor) — usado como color de acento fijo, en modo
            // oscuro quedaba texto oscuro sobre fondo oscuro. indigo es legible
            // en los dos temas, igual que teal para "taller".
            Expanded(flex: 2, child: Align(
              alignment: Alignment.center,
              child: AAMBadge(
                label: subjectTypeLabel(m.subjectType),
                color: m.subjectType == SubjectType.workshop ? AAMColors.teal : AAMColors.indigo,
              ),
            )),
            Expanded(flex: 4, child: Align(
              alignment: Alignment.center,
              child: Tooltip(
                message: _aniosAsignadosLabel(m),
                waitDuration: const Duration(milliseconds: 500),
                child: Text(_aniosAsignadosLabel(m),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: m.applicability.isEmpty ? widget.theme.textSec : widget.theme.text,
                      fontStyle: m.applicability.isEmpty ? FontStyle.italic : FontStyle.normal,
                    )),
              ),
            )),
            Expanded(flex: 4, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _RowActionBtn(icon: Icons.edit_outlined, color: AAMColors.accent, tooltip: 'Editar materia (nombre y tipo)', onTap: widget.onEditarMateria),
              const SizedBox(width: 10),
              _RowActionBtn(icon: Icons.tag, tooltip: 'Editar identificador', onTap: widget.onEditarShortCode),
              const SizedBox(width: 10),
              _RowActionBtn(icon: Icons.tune, tooltip: 'Gestionar aplicabilidad', onTap: widget.onGestionar),
              const SizedBox(width: 10),
              if (m.isActive)
                _RowActionBtn(
                  icon: Icons.block_outlined,
                  color: AAMColors.highlight,
                  tooltip: 'Dar de baja',
                  onTap: widget.onToggleActivo,
                )
              else ...[
                _RowActionBtn(
                  icon: Icons.check_circle_outline,
                  color: AAMColors.success,
                  tooltip: 'Dar de alta',
                  onTap: widget.onToggleActivo,
                ),
                const SizedBox(width: 10),
                // Borrado físico: solo se puede una vez dada de baja — el
                // backend vuelve a validarlo, esto es solo para no mostrar
                // una acción que de entrada va a rechazar.
                _RowActionBtn(
                  icon: Icons.delete_outline,
                  color: AAMColors.danger,
                  tooltip: 'Eliminar definitivamente',
                  onTap: widget.onEliminar,
                ),
              ],
            ])),
          ]),
        ),
      ),
    );
  }
}

class _RowActionBtn extends StatefulWidget {
  const _RowActionBtn({required this.icon, required this.tooltip, required this.onTap, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  // Color fijo (p.ej. AAMColors.danger para "Eliminar"). Si es null, usa el
  // hover accent/textSec de siempre — las acciones "semánticas" (dar de
  // baja/alta, eliminar) sí llevan un color propio.
  final Color? color;

  @override
  State<_RowActionBtn> createState() => _RowActionBtnState();
}

class _RowActionBtnState extends State<_RowActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? (_hovered ? AAMColors.accent : AAMColors.textSec);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Icon(widget.icon, size: 18, color: color),
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
            Expanded(child: Text('El tipo se puede editar después desde la tabla de Materias.',
                style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec))),
          ]),
        ),
      ],
    );
  }
}

// ─── Editar materia (nombre + tipo) ────────────────────────────────────────
class _EditarMateriaForm extends StatefulWidget {
  const _EditarMateriaForm({required this.ds, required this.subject});
  final ApiDatasource ds;
  final Subject subject;

  @override
  State<_EditarMateriaForm> createState() => _EditarMateriaFormState();
}

class _EditarMateriaFormState extends State<_EditarMateriaForm> {
  late final TextEditingController _nombreCtrl;
  late SubjectType _tipo;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.subject.name);
    _tipo = widget.subject.subjectType;
  }

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
      await widget.ds.actualizarSubjectDetails(
        subjectId: widget.subject.id,
        name: _nombreCtrl.text.trim(),
        subjectType: _tipo,
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
      icon: Icons.edit_outlined,
      titulo: 'Editar materia',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      submitLabel: 'Guardar',
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
      ],
    );
  }
}

// ─── Identificador corto (short_code) ──────────────────────────────────────
class _ShortCodeForm extends StatefulWidget {
  const _ShortCodeForm({required this.ds, required this.subject});
  final ApiDatasource ds;
  final Subject subject;

  @override
  State<_ShortCodeForm> createState() => _ShortCodeFormState();
}

class _ShortCodeFormState extends State<_ShortCodeForm> {
  late final TextEditingController _ctrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.subject.shortCode);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.ds.actualizarSubjectShortCode(
        subjectId: widget.subject.id,
        shortCode: _ctrl.text.trim(),
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
      icon: Icons.tag,
      titulo: 'Identificador — ${widget.subject.name}',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      submitLabel: 'Guardar',
      children: [
        _FieldGroup(label: 'Identificador corto', child: _textInput(_ctrl, 'Ej: M1r4t')),
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
            Expanded(child: Text(
                'Se genera solo a partir del nombre y los años/especialidades asignados. '
                'Editalo a mano solo si coincide con el de otra materia — '
                'dejá el campo vacío para volver a generarlo automáticamente.',
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
