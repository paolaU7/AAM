import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/academic.dart';
import '../../domain/entities/course.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../widgets/aam_design_system.dart';
import '../widgets/auto_refresh_mixin.dart';

/// Catálogo de profesores (dato de referencia — nombre + contacto, sin login
/// ni usuario propio) y, por cada uno, qué materia dicta en qué curso. Esto
/// es exactamente `course_subject_teachers` — la misma asignación que se ve
/// desde la pestaña "Materias y profesores" de un curso, solo que gestionada
/// acá desde la ficha del profesor. No distingue grupo de taller (A/B) ni
/// reemplazos puntuales — eso vive en el horario detallado de cada curso.
class TeachersScreen extends StatefulWidget {
  const TeachersScreen({super.key});

  @override
  State<TeachersScreen> createState() => _TeachersScreenState();
}

const double _kFiltroAltura = 40.0;

class _TeachersScreenState extends State<TeachersScreen> with AutoRefreshMixin<TeachersScreen> {
  final ApiDatasource _ds = ApiDatasource();

  List<Teacher>? _profesores;
  List<Subject> _materias = [];
  bool _loading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _filterMateriaShortCode;

  @override
  void initState() {
    super.initState();
    _cargar();
    startAutoRefresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void onAutoRefresh() => _cargar(silent: true);

  Future<void> _cargar({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await _ds.getTeachers();
      List<Subject> materias = [];
      try {
        materias = await _ds.getSubjects();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _profesores = data;
          _materias = materias;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _error = 'Error al cargar profesores');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  List<String> get _shortCodesDisponibles {
    final Set<String> codes = {};
    for (final s in _materias) {
      final c = s.shortCode.trim();
      if (c.isNotEmpty) codes.add(c);
    }
    for (final p in _profesores ?? const <Teacher>[]) {
      for (final a in p.assignments) {
        final rawCode = a.subjectShortCode.trim();
        final c = rawCode.isNotEmpty ? rawCode : a.subjectName.trim();
        if (c.isNotEmpty) codes.add(c);
      }
    }
    final list = codes.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  bool get _hayFiltrosActivos =>
      _searchQuery.isNotEmpty || _filterMateriaShortCode != null;

  void _limpiarFiltros() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _filterMateriaShortCode = null;
    });
  }

  List<Teacher> _applyFilters(List<Teacher> profesores) {
    final q = _searchQuery.trim().toLowerCase();
    final filterCode = _filterMateriaShortCode?.trim().toLowerCase();
    return profesores.where((p) {
      final matchSearch = q.isEmpty ||
          p.fullName.toLowerCase().contains(q) ||
          (p.email != null && p.email!.toLowerCase().contains(q));
      final matchMateria = filterCode == null ||
          p.assignments.any((a) {
            final rawCode = a.subjectShortCode.trim();
            final code = rawCode.isNotEmpty ? rawCode : a.subjectName.trim();
            return code.toLowerCase() == filterCode;
          });
      return matchSearch && matchMateria;
    }).toList();
  }

  Future<void> _abrirNuevoProfesor() async {
    final creado = await showDialog<Teacher>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevoProfesorForm(ds: _ds),
    );
    if (creado != null) _cargar();
  }

  Future<void> _verAsignaciones(Teacher t) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _AsignacionesModal(ds: _ds, teacher: t),
    );
  }

  Future<void> _editarProfesor(Teacher t) async {
    final updated = await showDialog<Teacher>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _EditarProfesorForm(ds: _ds, teacher: t),
    );
    if (updated != null) _cargar();
  }

  Future<void> _gestionarLicencia(Teacher t) async {
    final updated = await showDialog<Teacher>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _LicenciaProfesorForm(ds: _ds, teacher: t),
    );
    if (updated != null) _cargar();
  }

  Future<void> _darDeBaja(Teacher t) async {
    final updated = await showDialog<Teacher>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _BajaProfesorForm(ds: _ds, teacher: t),
    );
    if (updated != null) _cargar();
  }

  Future<void> _reactivar(Teacher t) async {
    try {
      await _ds.cambiarEstadoTeacher(id: t.id, status: 'active');
      _cargar();
    } catch (e) {
      if (mounted) _showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _eliminarProfesor(Teacher t) async {
    final ok = await showAamConfirmDialog(
      context,
      titulo: 'Eliminar profesor',
      mensaje: '¿Eliminar a "${t.fullName}" definitivamente? Esta acción no se puede deshacer. '
          'Si tiene materias asignadas o clases en el horario, no va a poder eliminarse.',
    );
    if (!ok) return;
    try {
      await _ds.eliminarTeacher(t.id);
      _cargar();
    } catch (e) {
      if (mounted) _showError(context, e.toString().replaceFirst('Exception: ', ''));
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
    final todas = _profesores ?? [];
    final filtrados = _applyFilters(todas);
    return Column(children: [
      AAMTopbar(
        title: 'Profesores',
        actions: [
          AAMButton(label: 'Nuevo profesor', icon: Icons.add, onPressed: _abrirNuevoProfesor),
        ],
      ),
      Expanded(
        child: _loading && _profesores == null
            ? const AAMLoadingScreen()
            : _error != null && _profesores == null
                ? AAMErrorWidget(message: _error!, onRetry: _cargar)
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      _buildFiltros(theme, todas.length, filtrados.length),
                      const SizedBox(height: 20),
                      Expanded(child: _buildTabla(filtrados, theme)),
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
              controller: _searchCtrl,
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
      _filterBox(theme, AAMDropdown<String?>(
        value: _filterMateriaShortCode,
        options: <String?>[null, ..._shortCodesDisponibles],
        itemLabel: (c) => c ?? 'Materia: todas',
        fontSize: 13,
        isDense: true,
        onChanged: (v) => setState(() => _filterMateriaShortCode = v),
      )),
      const SizedBox(width: 12),
      _buildLimpiarFiltros(theme),
      const SizedBox(width: 12),
      Text('$filtrado de $total profesores', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
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

  Widget _buildTabla(List<Teacher> profesores, AAMTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const AAMTableHeader(columns: [
          ('Nombre', 3),
          ('Estado', 2),
          ('Materias asignadas', 3),
          ('Email', 2),
          ('Teléfono', 2),
          ('Acciones', 3),
        ]),
        Expanded(
          child: profesores.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 40, color: theme.borderCol),
                    const SizedBox(height: 12),
                    Text(
                      _hayFiltrosActivos
                          ? 'No hay profesores que coincidan con los filtros'
                          : 'No hay profesores cargados',
                      style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec),
                    ),
                    const SizedBox(height: 8),
                    if (!_hayFiltrosActivos)
                      AAMButton(label: 'Crear primer profesor', onPressed: _abrirNuevoProfesor)
                    else
                      AAMButton(label: 'Limpiar filtros', onPressed: _limpiarFiltros),
                  ],
                ))
              : ListView.builder(
                  itemCount: profesores.length,
                  itemBuilder: (ctx, i) => _ProfesorRow(
                    profesor: profesores[i],
                    theme: theme,
                    onVerAsignaciones: () => _verAsignaciones(profesores[i]),
                    onEditar: () => _editarProfesor(profesores[i]),
                    onLicencia: () => _gestionarLicencia(profesores[i]),
                    onBaja: () => _darDeBaja(profesores[i]),
                    onReactivar: () => _reactivar(profesores[i]),
                    onEliminar: () => _eliminarProfesor(profesores[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _ProfesorRow extends StatefulWidget {
  const _ProfesorRow({
    required this.profesor,
    required this.theme,
    required this.onVerAsignaciones,
    required this.onEditar,
    required this.onLicencia,
    required this.onBaja,
    required this.onReactivar,
    required this.onEliminar,
  });

  final Teacher profesor;
  final AAMTheme theme;
  final VoidCallback onVerAsignaciones;
  final VoidCallback onEditar;
  final VoidCallback onLicencia;
  final VoidCallback onBaja;
  final VoidCallback onReactivar;
  final VoidCallback onEliminar;

  @override
  State<_ProfesorRow> createState() => _ProfesorRowState();
}

class _ProfesorRowState extends State<_ProfesorRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profesor;
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
          Expanded(flex: 3, child: Text(p.fullName,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text))),
          Expanded(flex: 2, child: Center(child: _TeacherStatusBadge(teacher: p, theme: widget.theme))),
          Expanded(flex: 3, child: Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: widget.onVerAsignaciones,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: p.assignments.isEmpty
                    ? Text('Sin materias', style: GoogleFonts.dmSans(fontSize: 12, color: widget.theme.textSec))
                    : Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6, runSpacing: 4,
                        // Un profesor puede dar la misma materia en varios
                        // cursos (una fila de course_subject_teachers por
                        // curso) — acá se resume por materia, no por curso,
                        // así que se agrupa por subjectId para no repetir
                        // el mismo chip ("M1r4t", "M1r4t", "M1r4t"...). El
                        // detalle curso por curso está al hacer click.
                        children: {for (final a in p.assignments) a.subjectId: a}
                            .values
                            .map((a) => _ShortCodeChip(
                                  shortCode: a.subjectShortCode.isEmpty ? a.subjectName : a.subjectShortCode,
                                  theme: widget.theme,
                                ))
                            .toList(),
                      ),
              ),
            ),
          )),
          Expanded(flex: 2, child: Text(p.email ?? '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
          Expanded(flex: 2, child: Text(p.phone ?? '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
          Expanded(flex: 3, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _RowActionBtn(
              icon: Icons.assignment_outlined,
              tooltip: 'Ver materias asignadas',
              onTap: widget.onVerAsignaciones,
            ),
            const SizedBox(width: 8),
            _RowActionBtn(
              icon: Icons.edit_outlined,
              color: AAMColors.accent,
              tooltip: 'Editar profesor',
              onTap: widget.onEditar,
            ),
            const SizedBox(width: 8),
            _RowActionBtn(
              icon: Icons.event_busy_outlined,
              color: AAMColors.warning,
              tooltip: 'Licencia / Vacaciones',
              onTap: widget.onLicencia,
            ),
            const SizedBox(width: 8),
            if (p.isInactive) ...[
              _RowActionBtn(
                icon: Icons.check_circle_outline,
                color: AAMColors.success,
                tooltip: 'Reactivar (dar de alta)',
                onTap: widget.onReactivar,
              ),
              const SizedBox(width: 8),
              _RowActionBtn(
                icon: Icons.delete_outline,
                color: AAMColors.danger,
                tooltip: 'Eliminar definitivamente',
                onTap: widget.onEliminar,
              ),
            ] else ...[
              _RowActionBtn(
                icon: Icons.block_outlined,
                color: AAMColors.highlight,
                tooltip: 'Dar de baja',
                onTap: widget.onBaja,
              ),
            ],
          ])),
        ]),
      ),
    );
  }
}

// Mismo look que el chip de short_code en materias_screen.dart — así la
// misma "M1r4t" se ve igual en las dos pantallas.
class _ShortCodeChip extends StatelessWidget {
  const _ShortCodeChip({required this.shortCode, required this.theme});
  final String shortCode;
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.surfaceCol,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.borderCol),
      ),
      child: Text(shortCode,
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
    );
  }
}

class _RowActionBtn extends StatefulWidget {
  const _RowActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  State<_RowActionBtn> createState() => _RowActionBtnState();
}

class _RowActionBtnState extends State<_RowActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color != null ? widget.color!.withAlpha(180) : AAMColors.textSec;
    final hoverColor = widget.color ?? AAMColors.accent;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Icon(widget.icon, size: 18, color: _hovered ? hoverColor : baseColor),
        ),
      ),
    );
  }
}

class _TeacherStatusBadge extends StatelessWidget {
  const _TeacherStatusBadge({required this.teacher, required this.theme});
  final Teacher teacher;
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    final (label, Color col) = switch (teacher.status) {
      'active' => ('Activo', AAMColors.success),
      'inactive' => ('De baja', AAMColors.danger),
      'medical_leave' => ('Lic. médica', AAMColors.warning),
      'vacation' => ('Vacaciones', AAMColors.primary),
      _ => (teacher.status, theme.textSec),
    };

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: col.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: col.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: col)),
        ],
      ),
    );

    final tieneDetalle = (teacher.statusReason != null && teacher.statusReason!.trim().isNotEmpty) ||
        (teacher.returnDate != null && teacher.returnDate!.trim().isNotEmpty);

    if (tieneDetalle) {
      final buffer = StringBuffer();
      if (teacher.statusReason != null && teacher.statusReason!.trim().isNotEmpty) {
        buffer.writeln('Motivo: ${teacher.statusReason}');
      }
      if (teacher.returnDate != null && teacher.returnDate!.trim().isNotEmpty) {
        buffer.write('Retorno estimado: ${teacher.returnDate}');
      }
      return Tooltip(
        message: buffer.toString().trim(),
        child: badge,
      );
    }

    return badge;
  }
}

// ─── Nuevo profesor ─────────────────────────────────────────────────────────
class _NuevoProfesorForm extends StatefulWidget {
  const _NuevoProfesorForm({required this.ds});
  final ApiDatasource ds;

  @override
  State<_NuevoProfesorForm> createState() => _NuevoProfesorFormState();
}

class _NuevoProfesorFormState extends State<_NuevoProfesorForm> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá el nombre del profesor.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final creado = await widget.ds.crearTeacher(
        fullName: _nombreCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _telefonoCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(creado);
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
      icon: Icons.person_add_outlined,
      titulo: 'Nuevo profesor',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      submitLabel: 'Crear profesor',
      children: [
        _FieldGroup(label: 'Nombre completo', child: _textInput(_nombreCtrl, 'Ej: Marta Gómez')),
        const SizedBox(height: 16),
        _FieldGroup(label: 'Email (opcional)', child: _textInput(_emailCtrl, 'Ej: marta.gomez@mail.com', keyboard: TextInputType.emailAddress)),
        const SizedBox(height: 16),
        _FieldGroup(label: 'Teléfono (opcional)', child: _textInput(_telefonoCtrl, 'Ej: 11 5555-5555', keyboard: TextInputType.phone)),
        const SizedBox(height: 6),
        Text('Dato de referencia — no se crea un usuario ni se le da acceso a la app.',
            style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
      ],
    );
  }
}

// ─── Asignaciones del profesor (curso + materia) ───────────────────────────
class _AsignacionesModal extends StatefulWidget {
  const _AsignacionesModal({required this.ds, required this.teacher});
  final ApiDatasource ds;
  final Teacher teacher;

  @override
  State<_AsignacionesModal> createState() => _AsignacionesModalState();
}

class _AsignacionesModalState extends State<_AsignacionesModal> {
  List<SubjectTeacherAssignment> _asignaciones = [];
  List<Course> _cursos = [];
  List<Subject> _materiasDisponibles = [];
  bool _catalogosLoading = true;
  bool _materiasLoading = false;
  bool _submitting = false;
  String? _error;

  Course? _cursoSel;
  Subject? _materiaSel;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _catalogosLoading = true);
    try {
      final results = await Future.wait([
        widget.ds.getTeacherAssignments(widget.teacher.id),
        widget.ds.getCursos(),
      ]);
      if (!mounted) return;
      setState(() {
        _asignaciones = results[0] as List<SubjectTeacherAssignment>;
        _cursos = results[1] as List<Course>;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar las asignaciones.');
    } finally {
      if (mounted) setState(() => _catalogosLoading = false);
    }
  }

  // Las materias ofrecidas dependen del curso elegido — solo lo habilitado
  // para su año de cursada + especialidad (mismo filtro que en el horario
  // de un curso; ver `_AsignarMateriaForm` en cursos_screen.dart).
  Future<void> _onCursoChanged(Course? c) async {
    setState(() {
      _cursoSel = c;
      _materiaSel = null;
      _materiasDisponibles = [];
    });
    if (c == null) return;
    setState(() => _materiasLoading = true);
    try {
      final data = await widget.ds.getSubjects(gradeYear: c.gradeYear, specialtyId: c.specialtyId);
      if (mounted) setState(() => _materiasDisponibles = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar las materias del curso.');
    } finally {
      if (mounted) setState(() => _materiasLoading = false);
    }
  }

  Future<void> _agregar() async {
    if (_cursoSel == null || _materiaSel == null) {
      setState(() => _error = 'Seleccioná el curso y la materia.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.ds.asignarCourseSubjectTeacher(
        courseId: _cursoSel!.id, subjectId: _materiaSel!.id, teacherId: widget.teacher.id,
      );
      if (mounted) setState(() { _cursoSel = null; _materiaSel = null; _materiasDisponibles = []; });
      await _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _quitar(SubjectTeacherAssignment a) async {
    final ok = await showAamConfirmDialog(context,
        titulo: 'Quitar asignación',
        mensaje: '¿Quitar a ${widget.teacher.fullName} de "${a.subjectName}" en ${a.courseName ?? "ese curso"}? '
            'El horario detallado que use esta materia en ese curso dejará de tener profesor asignado.');
    if (!ok) return;
    try {
      await widget.ds.quitarCourseSubjectTeacher(a.courseId, a.subjectId);
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
        width: 560,
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
                      child: const Icon(Icons.assignment_outlined, size: 18, color: AAMColors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Asignaciones — ${widget.teacher.fullName}',
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
                  if (_asignaciones.isEmpty)
                    Text('Todavía no tiene materias asignadas.', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))
                  else
                    ..._asignaciones.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(a.subjectName, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text)),
                                  const SizedBox(width: 8),
                                  // AAMColors.primary (navy de modo claro) como color
                                  // fijo quedaba ilegible en modo oscuro — indigo se
                                  // lee en los dos temas, igual que teal para "taller".
                                  AAMBadge(
                                    label: subjectTypeLabel(a.subjectType),
                                    color: a.subjectType == SubjectType.workshop ? AAMColors.teal : AAMColors.indigo,
                                  ),
                                ]),
                                Text(a.courseName ?? '', style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
                              ])),
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
                  Text('Agregar asignación', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text)),
                  const SizedBox(height: 12),
                  AAMLabeledDropdown<Course>(
                    label: 'Curso',
                    value: _cursoSel,
                    options: _cursos,
                    hint: 'Curso',
                    itemLabel: (c) => c.name,
                    onChanged: _onCursoChanged,
                  ),
                  const SizedBox(height: 16),
                  if (_cursoSel != null && !_materiasLoading && _materiasDisponibles.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AAMColors.warning.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          'Este curso no tiene materias habilitadas para su año/especialidad. Configuralas desde la sección Materias.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
                    )
                  else
                    AAMLabeledDropdown<Subject>(
                      label: 'Materia',
                      value: _materiaSel,
                      options: _materiasDisponibles,
                      hint: _cursoSel == null ? 'Elegí el curso primero' : 'Materia',
                      itemLabel: (m) => '${m.name} (${subjectTypeLabel(m.subjectType)})',
                      onChanged: _cursoSel == null ? null : (v) => setState(() => _materiaSel = v),
                    ),
                  const SizedBox(height: 14),
                  if (_error != null) ...[
                    Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger)),
                    const SizedBox(height: 10),
                  ],
                  AAMButton(
                    label: _submitting ? 'Agregando…' : 'Agregar',
                    icon: Icons.add,
                    onPressed: _submitting ? null : _agregar,
                  ),
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

// ─── Modal Error ─────────────────────────────────────────────────────────────
void _showError(BuildContext context, String mensaje) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
    builder: (_) => _TeacherErrorModal(mensaje: mensaje),
  );
}

class _TeacherErrorModal extends StatelessWidget {
  const _TeacherErrorModal({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderCol),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.error_outline, size: 22, color: AAMColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text('Acción bloqueada',
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text))),
          ]),
          const SizedBox(height: 12),
          Text(mensaje, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: AAMButton(
              label: 'Entendido',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Modal Editar Profesor ────────────────────────────────────────────────────
class _EditarProfesorForm extends StatefulWidget {
  const _EditarProfesorForm({required this.ds, required this.teacher});
  final ApiDatasource ds;
  final Teacher teacher;

  @override
  State<_EditarProfesorForm> createState() => _EditarProfesorFormState();
}

class _EditarProfesorFormState extends State<_EditarProfesorForm> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _telefonoCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.teacher.fullName);
    _emailCtrl = TextEditingController(text: widget.teacher.email ?? '');
    _telefonoCtrl = TextEditingController(text: widget.teacher.phone ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre completo es obligatorio.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final updated = await widget.ds.actualizarTeacher(
        id: widget.teacher.id,
        fullName: nombre,
        email: _emailCtrl.text.trim(),
        phone: _telefonoCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderCol),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Editar profesor',
                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
            IconButton(
              icon: Icon(Icons.close, size: 20, color: theme.textSec),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
          const SizedBox(height: 18),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AAMColors.danger.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AAMColors.danger.withAlpha(80)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: AAMColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger))),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          _inputGroup('Nombre completo *', AAMTextField(controller: _nombreCtrl, hintText: 'Ej. Juan Pérez')),
          const SizedBox(height: 14),
          _inputGroup('Email', AAMTextField(controller: _emailCtrl, hintText: 'juan.perez@escuela.edu.ar')),
          const SizedBox(height: 14),
          _inputGroup('Teléfono', AAMTextField(controller: _telefonoCtrl, hintText: 'Ej. 223-5551234')),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AAMButton(
              label: 'Cancelar',
              variant: AAMButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 12),
            AAMButton(
              label: _submitting ? 'Guardando...' : 'Guardar cambios',
              onPressed: _submitting ? null : _submit,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _inputGroup(String label, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AAMTheme().textSec)),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

// ─── Modal Licencia / Vacaciones ──────────────────────────────────────────────
class _LicenciaProfesorForm extends StatefulWidget {
  const _LicenciaProfesorForm({required this.ds, required this.teacher});
  final ApiDatasource ds;
  final Teacher teacher;

  @override
  State<_LicenciaProfesorForm> createState() => _LicenciaProfesorFormState();
}

class _LicenciaProfesorFormState extends State<_LicenciaProfesorForm> {
  late String _status;
  late final TextEditingController _motivoCtrl;
  late final TextEditingController _retornoCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.teacher.status == 'inactive' ? 'medical_leave' : widget.teacher.status;
    if (_status == 'active') _status = 'medical_leave';
    _motivoCtrl = TextEditingController(text: widget.teacher.statusReason ?? '');
    _retornoCtrl = TextEditingController(text: widget.teacher.returnDate ?? '');
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _retornoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final updated = await widget.ds.cambiarEstadoTeacher(
        id: widget.teacher.id,
        status: _status,
        reason: _motivoCtrl.text.trim(),
        returnDate: _retornoCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderCol),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Licencia o vacaciones',
                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
            IconButton(
              icon: Icon(Icons.close, size: 20, color: theme.textSec),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Profesor: ${widget.teacher.fullName}',
            style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AAMColors.danger.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AAMColors.danger.withAlpha(80)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: AAMColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger))),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          _inputGroup('Estado asignado', AAMDropdown<String>(
            value: _status,
            options: const ['medical_leave', 'vacation', 'active'],
            itemLabel: (s) => switch (s) {
              'medical_leave' => 'Licencia médica',
              'vacation' => 'Vacaciones',
              'active' => 'Activo (finalizar licencia)',
              _ => s,
            },
            isExpanded: true,
            onChanged: (v) {
              if (v != null) setState(() => _status = v);
            },
          )),
          const SizedBox(height: 14),
          _inputGroup('Motivo (opcional)', AAMTextField(controller: _motivoCtrl, hintText: 'Ej. Reposo por prescripción médica')),
          const SizedBox(height: 14),
          _inputGroup('Fecha estimada de retorno (AAAA-MM-DD)', AAMTextField(controller: _retornoCtrl, hintText: 'Ej. 2026-10-15')),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AAMButton(
              label: 'Cancelar',
              variant: AAMButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 12),
            AAMButton(
              label: _submitting ? 'Guardando...' : 'Guardar',
              onPressed: _submitting ? null : _submit,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _inputGroup(String label, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AAMTheme().textSec)),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

// ─── Modal Confirmar Baja ─────────────────────────────────────────────────────
class _BajaProfesorForm extends StatefulWidget {
  const _BajaProfesorForm({required this.ds, required this.teacher});
  final ApiDatasource ds;
  final Teacher teacher;

  @override
  State<_BajaProfesorForm> createState() => _BajaProfesorFormState();
}

class _BajaProfesorFormState extends State<_BajaProfesorForm> {
  final _motivoCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final updated = await widget.ds.cambiarEstadoTeacher(
        id: widget.teacher.id,
        status: 'inactive',
        reason: _motivoCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderCol),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.block_outlined, size: 22, color: AAMColors.highlight),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Dar de baja profesor',
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            '¿Confirmas dar de baja a "${widget.teacher.fullName}"? El profesor pasará a estado inactivo.',
            style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AAMColors.danger.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AAMColors.danger.withAlpha(80)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: AAMColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger))),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Motivo de la baja (opcional)',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
            const SizedBox(height: 6),
            AAMTextField(controller: _motivoCtrl, hintText: 'Ej. Renuncia, pase de institución...'),
          ]),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AAMButton(
              label: 'Cancelar',
              variant: AAMButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 12),
            AAMButton(
              label: _submitting ? 'Procesando...' : 'Confirmar baja',
              onPressed: _submitting ? null : _submit,
            ),
          ]),
        ]),
      ),
    );
  }
}
