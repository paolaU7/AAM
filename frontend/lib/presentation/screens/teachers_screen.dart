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

class _TeachersScreenState extends State<TeachersScreen> with AutoRefreshMixin<TeachersScreen> {
  final ApiDatasource _ds = ApiDatasource();

  List<Teacher>? _profesores;
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
      final data = await _ds.getTeachers();
      if (mounted) setState(() { _profesores = data; _error = null; });
    } catch (_) {
      if (mounted && !silent) setState(() => _error = 'Error al cargar profesores');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
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
        title: 'Profes',
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
                    child: _buildTabla(_profesores ?? [], theme),
                  ),
      ),
    ]);
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
          ('Email', 3),
          ('Teléfono', 2),
          ('', 2),
        ]),
        Expanded(
          child: profesores.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 40, color: theme.borderCol),
                    const SizedBox(height: 12),
                    Text('No hay profesores cargados', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
                    const SizedBox(height: 8),
                    AAMButton(label: 'Crear primer profesor', onPressed: _abrirNuevoProfesor),
                  ],
                ))
              : ListView.builder(
                  itemCount: profesores.length,
                  itemBuilder: (ctx, i) => _ProfesorRow(
                    profesor: profesores[i],
                    theme: theme,
                    onVerAsignaciones: () => _verAsignaciones(profesores[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _ProfesorRow extends StatefulWidget {
  const _ProfesorRow({required this.profesor, required this.theme, required this.onVerAsignaciones});
  final Teacher profesor;
  final AAMTheme theme;
  final VoidCallback onVerAsignaciones;

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
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text))),
          Expanded(flex: 3, child: Text(p.email ?? '—',
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
          Expanded(flex: 2, child: Text(p.phone ?? '—',
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
          Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _RowActionBtn(icon: Icons.assignment_outlined, tooltip: 'Ver asignaciones', onTap: widget.onVerAsignaciones),
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
                                  AAMBadge(
                                    label: subjectTypeLabel(a.subjectType),
                                    color: a.subjectType == SubjectType.workshop ? AAMColors.teal : AAMColors.primary,
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
