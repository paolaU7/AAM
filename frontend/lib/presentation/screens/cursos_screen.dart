import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/workshop_group.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/entities/class_period.dart';
import '../../domain/entities/academic.dart';
import '../../domain/entities/preceptor_assignment.dart';
import '../../domain/entities/user.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../../infrastructure/repositories/course_repository_impl.dart';
import '../../infrastructure/repositories/time_slot_repository_impl.dart';
import '../widgets/aam_design_system.dart';

/// Sección "Cursos" del panel de Dirección. Reemplaza a la antigua pantalla
/// independiente de Horarios: el turno principal y el horario detallado
/// ahora viven acá, dentro de la pestaña "Horario" del curso seleccionado.
class CursosScreen extends StatefulWidget {
  const CursosScreen({super.key});

  @override
  State<CursosScreen> createState() => _CursosScreenState();
}

class _CursosScreenState extends State<CursosScreen> {
  final ApiDatasource _ds = ApiDatasource();
  late final CourseRepositoryImpl _courseRepo;

  List<Course> _cursos = [];
  bool _loading = true;
  String? _error;
  Course? _seleccionado;

  @override
  void initState() {
    super.initState();
    _courseRepo = CourseRepositoryImpl(_ds);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cursos = await _courseRepo.getCourses();
      if (mounted) setState(() => _cursos = cursos);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los cursos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirNuevoCurso() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevoCursoForm(ds: _ds),
    );
    if (result == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        if (_seleccionado != null) {
          return _CursoDetalle(
            curso: _seleccionado!,
            ds: _ds,
            onBack: () => setState(() => _seleccionado = null),
          );
        }
        return _buildLista(theme);
      },
    );
  }

  Widget _buildLista(AAMTheme theme) {
    return Column(children: [
      const AAMTopbar(title: 'Cursos'),
      Expanded(
        child: _loading
            ? const AAMLoadingScreen()
            : _error != null
                ? AAMErrorWidget(message: _error!, onRetry: _cargar)
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: _buildGrid(theme),
                  ),
      ),
    ]);
  }

  Widget _buildGrid(AAMTheme theme) {
    final cursos = [..._cursos]
      ..sort((a, b) {
        final byYear = b.academicYear.compareTo(a.academicYear);
        if (byYear != 0) return byYear;
        final byGrade = a.gradeYear.compareTo(b.gradeYear);
        if (byGrade != 0) return byGrade;
        return a.division.compareTo(b.division);
      });
    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          ...cursos.map((c) => _CursoCard(
                curso: c,
                theme: theme,
                onTap: () => setState(() => _seleccionado = c),
              )),
          _NuevoCursoCard(theme: theme, onTap: _abrirNuevoCurso),
        ],
      ),
    );
  }
}

class _CursoCard extends StatefulWidget {
  const _CursoCard({required this.curso, required this.theme, required this.onTap});
  final Course curso;
  final AAMTheme theme;
  final VoidCallback onTap;

  @override
  State<_CursoCard> createState() => _CursoCardState();
}

class _CursoCardState extends State<_CursoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final curso = widget.curso;
    final avatarSeed = curso.specialty ?? curso.name;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.card,
            border: Border.all(color: _hovered ? AAMColors.accent : theme.borderCol),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _InitialsAvatar(text: avatarSeed, color: avatarColorFor(avatarSeed)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(curso.name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text)),
                Text('Año lectivo ${curso.academicYear}', style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
              ])),
            ]),
            const SizedBox(height: 12),
            if (curso.specialty != null) AAMBadge(label: curso.specialty!, color: AAMColors.accent),
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.borderCol),
            const SizedBox(height: 10),
            Text('${curso.totalStudents} alumnos', style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
          ]),
        ),
      ),
    );
  }
}

class _NuevoCursoCard extends StatelessWidget {
  const _NuevoCursoCard({required this.theme, required this.onTap});
  final AAMTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: CustomPaint(
          painter: _DashedRRectPainter(color: AAMColors.accent, radius: 16),
          child: SizedBox(
            width: 240,
            height: 132,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add, size: 20, color: AAMColors.accent),
                const SizedBox(height: 6),
                Text('Nuevo curso', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AAMColors.accent)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Alta de curso ──────────────────────────────────────────────────────────
class _NuevoCursoForm extends StatefulWidget {
  const _NuevoCursoForm({required this.ds});
  final ApiDatasource ds;

  @override
  State<_NuevoCursoForm> createState() => _NuevoCursoFormState();
}

class _NuevoCursoFormState extends State<_NuevoCursoForm> {
  late final TextEditingController _anioLectivoCtrl;
  final _divisionCtrl = TextEditingController();
  final _especialidadCtrl = TextEditingController();
  int? _gradeYear;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _anioLectivoCtrl = TextEditingController(text: '${DateTime.now().year}');
  }

  @override
  void dispose() {
    _anioLectivoCtrl.dispose();
    _divisionCtrl.dispose();
    _especialidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final anio = int.tryParse(_anioLectivoCtrl.text.trim());
    if (anio == null || anio < 2000) {
      setState(() => _error = 'Ingresá un año lectivo válido.');
      return;
    }
    if (_gradeYear == null) {
      setState(() => _error = 'Seleccioná el año de cursada.');
      return;
    }
    final division = int.tryParse(_divisionCtrl.text.trim());
    if (division == null || division <= 0) {
      setState(() => _error = 'Ingresá una división válida (número mayor a 0).');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ds.crearCurso(
        academicYear: anio,
        gradeYear: _gradeYear!,
        division: division,
        specialty: _especialidadCtrl.text.trim().isEmpty ? null : _especialidadCtrl.text.trim(),
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
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8))],
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AAMColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.school_outlined, size: 18, color: AAMColors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Nuevo curso',
                      style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close, size: 16, color: theme.textSec),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: _FieldGroup(label: 'Año lectivo',
                      child: _textInput(_anioLectivoCtrl, 'Ej: 2026', keyboard: TextInputType.number))),
                  const SizedBox(width: 16),
                  Expanded(child: _DropdownGroup<int>(
                    label: 'Año de cursada',
                    value: _gradeYear,
                    options: const [1, 2, 3, 4, 5, 6, 7],
                    hint: 'Año de cursada',
                    itemLabel: gradeYearOrdinal,
                    onChanged: (v) => setState(() => _gradeYear = v),
                  )),
                ]),
                const SizedBox(height: 16),
                _FieldGroup(label: 'División',
                    child: _textInput(_divisionCtrl, 'Ej: 1', keyboard: TextInputType.number)),
                const SizedBox(height: 16),
                _FieldGroup(label: 'Especialidad (opcional)',
                    child: _textInput(_especialidadCtrl, 'Ej: Informática — vacío si es ciclo básico')),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.danger)),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec))),
                    ),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: GestureDetector(
                    onTap: _submitting ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _submitting ? AAMColors.accent.withAlpha((0.6 * 255).round()) : AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                          : Text('Crear curso', style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.white))),
                    ),
                  )),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─── Detalle de curso (lista + tabs) ────────────────────────────────────────
class _CursoDetalle extends StatefulWidget {
  const _CursoDetalle({required this.curso, required this.ds, required this.onBack});
  final Course curso;
  final ApiDatasource ds;
  final VoidCallback onBack;

  @override
  State<_CursoDetalle> createState() => _CursoDetalleState();
}

class _CursoDetalleState extends State<_CursoDetalle> {
  int _tabIndex = 0;
  static const _tabs = ['Datos generales', 'Horario', 'Materias y profesores', 'Preceptores'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Column(children: [
          _buildHeader(theme),
          _buildTabs(theme),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: switch (_tabIndex) {
                0 => _TabDatosGenerales(curso: widget.curso),
                1 => _TabHorario(curso: widget.curso, ds: widget.ds),
                2 => _TabMaterias(curso: widget.curso, ds: widget.ds),
                _ => _TabPreceptores(curso: widget.curso, ds: widget.ds),
              },
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildHeader(AAMTheme theme) {
    return Container(
      height: kHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border(bottom: BorderSide(color: theme.borderCol, width: 1)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: widget.onBack,
          child: Icon(Icons.arrow_back, size: 20, color: theme.text),
        ),
        const SizedBox(width: 16),
        Text(widget.curso.name,
            style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
        if (widget.curso.specialty != null) ...[
          const SizedBox(width: 10),
          AAMBadge(label: widget.curso.specialty!, color: AAMColors.accent),
        ],
      ]),
    );
  }

  Widget _buildTabs(AAMTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border(bottom: BorderSide(color: theme.borderCol, width: 1)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _TabChip(
            label: _tabs[i],
            selected: _tabIndex == i,
            theme: theme,
            onTap: () => setState(() => _tabIndex = i),
          ),
        )),
      ),
    );
  }
}

// ─── Tab: Datos generales ────────────────────────────────────────────────────
class _TabDatosGenerales extends StatelessWidget {
  const _TabDatosGenerales({required this.curso});
  final Course curso;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return _SectionCard(theme: theme, title: 'Datos del curso', children: [
      Row(children: [
        Expanded(child: _DetalleCampo(label: 'Año lectivo', valor: '${curso.academicYear}', theme: theme)),
        Expanded(child: _DetalleCampo(label: 'Año de cursada', valor: gradeYearOrdinal(curso.gradeYear), theme: theme)),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _DetalleCampo(label: 'División', valor: divisionOrdinal(curso.division), theme: theme)),
        Expanded(child: _DetalleCampo(label: 'Especialidad', valor: curso.specialty ?? 'Ciclo básico (sin especialidad)', theme: theme)),
      ]),
      const SizedBox(height: 20),
      _DetalleCampo(label: 'Total de alumnos', valor: '${curso.totalStudents}', theme: theme),
    ]);
  }
}

class _DetalleCampo extends StatelessWidget {
  const _DetalleCampo({required this.label, required this.valor, required this.theme});
  final String label;
  final String valor;
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
      const SizedBox(height: 4),
      Text(valor, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: theme.text)),
    ]);
  }
}

// ─── Tab: Horario (turno principal + horario detallado) ────────────────────
class _TabHorario extends StatefulWidget {
  const _TabHorario({required this.curso, required this.ds});
  final Course curso;
  final ApiDatasource ds;

  @override
  State<_TabHorario> createState() => _TabHorarioState();
}

class _TabHorarioState extends State<_TabHorario> {
  late final TimeSlotRepositoryImpl _timeSlotRepo;

  List<TimeSlot> _turnoPrincipal = [];
  // Curriculares (workshopGroupId null) + contraturno de TODOS los grupos
  // de taller del curso — el backend ya los combina en una sola respuesta.
  List<ClassPeriod> _detallado = [];
  List<SubjectTeacherAssignment> _materiasCurso = [];
  List<WorkshopGroup> _grupos = [];
  List<Teacher> _profesores = [];
  bool _loading = true;
  String? _error;

  // Qué grupo de taller se muestra en la grilla (la parte curricular de la
  // mañana es la misma para todos, no se repite por solapa).
  int _grupoTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _timeSlotRepo = TimeSlotRepositoryImpl(widget.ds);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _timeSlotRepo.getTimeSlotsByCourse(widget.curso.id),
        widget.ds.getClassPeriods(widget.curso.id),
        widget.ds.getCourseSubjectTeachers(widget.curso.id),
        widget.ds.getWorkshopGroupsByCourse(widget.curso.id),
        widget.ds.getTeachers(),
      ]);
      if (!mounted) return;
      setState(() {
        _turnoPrincipal = results[0] as List<TimeSlot>;
        _detallado = results[1] as List<ClassPeriod>;
        _materiasCurso = results[2] as List<SubjectTeacherAssignment>;
        _grupos = results[3] as List<WorkshopGroup>;
        _profesores = results[4] as List<Teacher>;
        if (_grupoTabIndex >= _grupos.length) _grupoTabIndex = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el horario del curso.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _agregarFranja() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevaFranjaForm(ds: widget.ds, courseId: widget.curso.id),
    );
    if (result == true) _cargar();
  }

  Future<void> _eliminarFranja(TimeSlot slot) async {
    final ok = await _confirmarEliminacion(context,
        titulo: 'Eliminar franja horaria',
        mensaje: '¿Eliminar la franja del ${_diaLabel(slot.dayOfWeek)} ${slot.startTime.label}–${slot.endTime.label}?');
    if (!ok) return;
    try {
      await widget.ds.eliminarTimeSlot(widget.curso.id, slot.id);
      _cargar();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo eliminar la franja horaria.');
    }
  }

  Future<void> _agregarPeriodo() async {
    if (_materiasCurso.isEmpty) {
      setState(() => _error = 'Asigná al menos una materia al curso antes de cargar el horario detallado.');
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevoPeriodoForm(
        ds: widget.ds,
        courseId: widget.curso.id,
        materias: _materiasCurso,
        grupos: _grupos,
        profesores: _profesores,
      ),
    );
    if (result == true) _cargar();
  }

  Future<void> _eliminarPeriodo(ClassPeriod p) async {
    final ok = await _confirmarEliminacion(context,
        titulo: 'Eliminar período',
        mensaje: '¿Eliminar el período del ${_diaLabel(p.dayOfWeek)} ${p.startTime.label}–${p.endTime.label}?');
    if (!ok) return;
    try {
      await widget.ds.eliminarClassPeriod(widget.curso.id, p.id);
      _cargar();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo eliminar el período.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    if (_loading) return const AAMLoadingScreen();

    final turno = [..._turnoPrincipal]
      ..sort((a, b) {
        final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (byDay != 0) return byDay;
        return a.startTime.compareTo(b.startTime);
      });

    final curriculares = _detallado.where((p) => p.workshopGroupId == null).toList();
    final contraturnoActivo = _grupos.isEmpty
        ? <ClassPeriod>[]
        : _detallado.where((p) => p.workshopGroupId == _grupos[_grupoTabIndex].id).toList();
    final periodosGrilla = [...curriculares, ...contraturnoActivo];

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_error != null) ...[
          Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.danger)),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(child: Text('Turno principal', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text))),
          _DashedButton(label: 'Agregar franja', onTap: _agregarFranja),
        ]),
        const SizedBox(height: 12),
        if (turno.isEmpty)
          _EmptyRow(theme: theme, mensaje: 'Sin franjas horarias cargadas.')
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: theme.card, border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(12)),
            child: Column(children: turno.map((s) => _FranjaRow(slot: s, theme: theme, onDelete: () => _eliminarFranja(s))).toList()),
          ),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: Text('Horario detallado', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text))),
          _DashedButton(label: 'Agregar período', onTap: _agregarPeriodo),
        ]),
        const SizedBox(height: 12),
        if (_grupos.isNotEmpty) ...[
          Row(children: List.generate(_grupos.length, (i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TabChip(
              label: 'Grupo ${_grupos[i].name}',
              selected: _grupoTabIndex == i,
              theme: theme,
              onTap: () => setState(() => _grupoTabIndex = i),
            ),
          ))),
          const SizedBox(height: 12),
        ],
        _HorarioGrilla(periodos: periodosGrilla, materiasCurso: _materiasCurso, theme: theme, onDeletePeriodo: _eliminarPeriodo),
        const SizedBox(height: 12),
        _LeyendaHorario(theme: theme),
      ]),
    );
  }
}

class _FranjaRow extends StatelessWidget {
  const _FranjaRow({required this.slot, required this.theme, required this.onDelete});
  final TimeSlot slot;
  final AAMTheme theme;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.borderCol, width: 1))),
      child: Row(children: [
        SizedBox(width: 90, child: Text(_diaLabel(slot.dayOfWeek), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text))),
        SizedBox(width: 130, child: Text('${slot.startTime.label} – ${slot.endTime.label}', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))),
        SizedBox(width: 100, child: AAMBadge(label: shiftTypeLabel(slot.shift), color: AAMColors.info)),
        const SizedBox(width: 12),
        Expanded(child: Text(activityTypeLabel(slot.activityType), style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))),
        if (slot.lateToleranceMinutes > 0)
          Text('Tolerancia: ${slot.lateToleranceMinutes} min', style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
        const SizedBox(width: 12),
        GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_outline, size: 18, color: AAMColors.danger)),
      ]),
    );
  }
}

/// Grilla semanal del horario detallado: cada bloque muestra la materia real
/// y el profesor a cargo (nunca un bloque genérico). Curriculares +
/// contraturno del grupo de taller activo, ya combinados por el caller.
class _HorarioGrilla extends StatelessWidget {
  const _HorarioGrilla({required this.periodos, required this.materiasCurso, required this.theme, required this.onDeletePeriodo});
  final List<ClassPeriod> periodos;
  final List<SubjectTeacherAssignment> materiasCurso;
  final AAMTheme theme;
  final ValueChanged<ClassPeriod> onDeletePeriodo;

  static const List<String> _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  bool _esSuplente(ClassPeriod p) {
    if (p.periodType != PeriodType.lesson || p.teacherId == null || p.subjectId == null) return false;
    SubjectTeacherAssignment? titular;
    try {
      titular = materiasCurso.firstWhere((m) => m.subjectId == p.subjectId);
    } catch (_) {
      return false;
    }
    return titular.teacherId != p.teacherId;
  }

  List<(ClockTime, ClockTime)> get _franjas {
    final set = <(ClockTime, ClockTime)>{};
    for (final p in periodos) {
      set.add((p.startTime, p.endTime));
    }
    final list = set.toList()..sort((a, b) => a.$1.compareTo(b.$1));
    return list;
  }

  List<ClassPeriod> _en(int dayOfWeek, ClockTime start, ClockTime end) => periodos
      .where((p) => p.dayOfWeek == dayOfWeek && p.startTime == start && p.endTime == end)
      .toList();

  @override
  Widget build(BuildContext context) {
    final franjas = _franjas;
    if (franjas.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(color: theme.card, border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text('Sin horario detallado cargado.', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))),
      );
    }

    const double colW = 160;
    const double hdrH = 40;

    return Container(
      decoration: BoxDecoration(color: theme.card, border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 60 + colW * _dias.length,
            child: Column(children: [
              Container(
                height: hdrH,
                color: theme.surfaceCol,
                child: Row(children: [
                  const SizedBox(width: 60),
                  ..._dias.map((d) => SizedBox(
                        width: colW,
                        child: Center(child: Text(d, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: theme.text))),
                      )),
                ]),
              ),
              Divider(height: 1, color: theme.borderCol),
              ...franjas.map((franja) {
                final (start, end) = franja;
                return Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.borderCol, width: 1))),
                  child: IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(width: 60, child: Center(child: Text(start.label, style: GoogleFonts.dmSans(fontSize: 10, color: theme.textSec)))),
                      for (var dow = 1; dow <= _dias.length; dow++)
                        SizedBox(width: colW, child: _celda(_en(dow, start, end))),
                    ]),
                  ),
                );
              }),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _celda(List<ClassPeriod> periodosCelda) {
    if (periodosCelda.isEmpty) return const SizedBox.shrink();
    return Column(children: periodosCelda.map(_celdaPeriodo).toList());
  }

  Widget _celdaPeriodo(ClassPeriod p) {
    return GestureDetector(
      onTap: () => onDeletePeriodo(p),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: switch (p.periodType) {
          PeriodType.recess => _celdaDashed('Recreo'),
          PeriodType.lunch => _celdaDashed('Almuerzo'),
          PeriodType.lesson => _celdaClase(p),
        },
      ),
    );
  }

  Widget _celdaDashed(String label) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: CustomPaint(
        painter: _DashedRRectPainter(color: theme.borderCol, radius: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
        ),
      ),
    );
  }

  Widget _celdaClase(ClassPeriod p) {
    final suplente = _esSuplente(p);
    final esTaller = p.workshopGroupId != null;
    final acento = esTaller ? AAMColors.teal : AAMColors.primary;
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: esTaller ? acento.withAlpha((0.16 * 255).round()) : acento.withAlpha((0.06 * 255).round()),
        border: Border.all(color: p.isFifthModule ? AAMColors.violet : acento, width: p.isFifthModule ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(p.subjectName ?? '—',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: theme.text), overflow: TextOverflow.ellipsis),
        Text(
          'Prof. ${p.teacherName ?? '—'}${suplente ? ' (suplente)' : ''}',
          style: GoogleFonts.dmSans(fontSize: 10, color: theme.textSec, fontStyle: suplente ? FontStyle.italic : FontStyle.normal),
          overflow: TextOverflow.ellipsis,
        ),
        if (p.isFifthModule)
          Text('5to módulo', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: AAMColors.violet)),
      ]),
    );
  }
}

class _LeyendaHorario extends StatelessWidget {
  const _LeyendaHorario({required this.theme});
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _swatch(AAMColors.primary, 'Curricular', outlined: true),
      _swatch(AAMColors.teal, 'Taller (contraturno)'),
      _swatchDashed('Recreo / Almuerzo'),
      _swatchDot(AAMColors.violet, '5to módulo'),
      Text('Prof. (suplente) = reemplazo temporal',
          style: GoogleFonts.dmSans(fontSize: 11, fontStyle: FontStyle.italic, color: theme.textSec)),
    ]);
  }

  Widget _swatch(Color color, String label, {bool outlined = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withAlpha((0.25 * 255).round()),
          border: Border.all(color: color, width: outlined ? 1.5 : 1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
    ]);
  }

  Widget _swatchDashed(String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 14, height: 14, child: CustomPaint(painter: _DashedRRectPainter(color: theme.textSec, radius: 3))),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
    ]);
  }

  Widget _swatchDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
    ]);
  }
}

// ─── Alta de franja (turno principal) ───────────────────────────────────────
class _NuevaFranjaForm extends StatefulWidget {
  const _NuevaFranjaForm({required this.ds, required this.courseId});
  final ApiDatasource ds;
  final String courseId;

  @override
  State<_NuevaFranjaForm> createState() => _NuevaFranjaFormState();
}

class _NuevaFranjaFormState extends State<_NuevaFranjaForm> {
  ShiftType _shift = ShiftType.morning;
  ActivityType _activityType = ActivityType.mainShift;
  int? _dayOfWeek;
  ClockTime? _start;
  ClockTime? _end;
  final _toleranciaCtrl = TextEditingController(text: '0');

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _toleranciaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final t = await _pickTime(context, _start);
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await _pickTime(context, _end);
    if (t != null) setState(() => _end = t);
  }

  Future<void> _submit() async {
    if (_dayOfWeek == null) {
      setState(() => _error = 'Seleccioná el día.');
      return;
    }
    if (_start == null || _end == null) {
      setState(() => _error = 'Seleccioná el horario de inicio y fin.');
      return;
    }
    if (_end!.compareTo(_start!) <= 0) {
      setState(() => _error = 'El horario de fin debe ser posterior al de inicio.');
      return;
    }
    final tolerancia = int.tryParse(_toleranciaCtrl.text.trim()) ?? 0;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ds.crearTimeSlotDeCurso(
        courseId: widget.courseId,
        shift: _shift,
        activityType: _activityType,
        dayOfWeek: _dayOfWeek!,
        startTime: _start!,
        endTime: _end!,
        lateToleranceMinutes: tolerancia,
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
    return _FormDialog(
      theme: theme,
      icon: Icons.schedule_outlined,
      titulo: 'Nueva franja horaria',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(false),
      onSubmit: _submit,
      submitLabel: 'Crear franja',
      children: [
        Row(children: [
          Expanded(child: _DropdownGroup<int>(
            label: 'Día', value: _dayOfWeek, options: const [1, 2, 3, 4, 5, 6, 7],
            hint: 'Día', itemLabel: _diaLabel, onChanged: (v) => setState(() => _dayOfWeek = v),
          )),
          const SizedBox(width: 16),
          Expanded(child: _DropdownGroup<ShiftType>(
            label: 'Turno', value: _shift, options: ShiftType.values,
            itemLabel: shiftTypeLabel, onChanged: (v) => setState(() => _shift = v!),
          )),
        ]),
        const SizedBox(height: 16),
        _DropdownGroup<ActivityType>(
          label: 'Tipo de actividad',
          value: _activityType,
          options: const [ActivityType.mainShift, ActivityType.afterShift],
          itemLabel: activityTypeLabel,
          onChanged: (v) => setState(() => _activityType = v!),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _TimeButtonField(label: 'Hora de inicio', value: _start, onTap: _pickStart)),
          const SizedBox(width: 16),
          Expanded(child: _TimeButtonField(label: 'Hora de fin', value: _end, onTap: _pickEnd)),
        ]),
        const SizedBox(height: 16),
        _FieldGroup(label: 'Tolerancia de llegada tarde (minutos)',
            child: _textInput(_toleranciaCtrl, '0', keyboard: TextInputType.number)),
      ],
    );
  }
}

// ─── Alta de período (horario detallado) ────────────────────────────────────
class _NuevoPeriodoForm extends StatefulWidget {
  const _NuevoPeriodoForm({
    required this.ds,
    required this.courseId,
    required this.materias,
    required this.grupos,
    required this.profesores,
  });
  final ApiDatasource ds;
  final String courseId;
  final List<SubjectTeacherAssignment> materias;
  final List<WorkshopGroup> grupos;
  final List<Teacher> profesores;

  @override
  State<_NuevoPeriodoForm> createState() => _NuevoPeriodoFormState();
}

class _NuevoPeriodoFormState extends State<_NuevoPeriodoForm> {
  int? _dayOfWeek;
  ShiftType _shift = ShiftType.morning;
  PeriodType _periodType = PeriodType.lesson;
  ClockTime? _start;
  ClockTime? _end;
  bool _quintoModulo = false;
  SubjectTeacherAssignment? _materiaSel;
  Teacher? _profesorSel;
  // null = curricular (compartido por todos los grupos).
  WorkshopGroup? _grupoSel;

  bool _submitting = false;
  String? _error;

  Future<void> _pickStart() async {
    final t = await _pickTime(context, _start);
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await _pickTime(context, _end);
    if (t != null) setState(() => _end = t);
  }

  void _onMateriaChanged(SubjectTeacherAssignment? m) {
    setState(() {
      _materiaSel = m;
      if (m == null) {
        _profesorSel = null;
        return;
      }
      try {
        _profesorSel = widget.profesores.firstWhere((p) => p.id == m.teacherId);
      } catch (_) {
        _profesorSel = null;
      }
    });
  }

  Future<void> _submit() async {
    if (_dayOfWeek == null) {
      setState(() => _error = 'Seleccioná el día.');
      return;
    }
    if (_start == null || _end == null) {
      setState(() => _error = 'Seleccioná el horario de inicio y fin.');
      return;
    }
    if (_end!.compareTo(_start!) <= 0) {
      setState(() => _error = 'El horario de fin debe ser posterior al de inicio.');
      return;
    }
    if (_periodType == PeriodType.lesson && (_materiaSel == null || _profesorSel == null)) {
      setState(() => _error = 'Seleccioná la materia y el profesor a cargo.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ds.crearClassPeriod(
        courseId: widget.courseId,
        dayOfWeek: _dayOfWeek!,
        shift: _shift,
        periodType: _periodType,
        startTime: _start!,
        endTime: _end!,
        subjectId: _periodType == PeriodType.lesson ? _materiaSel!.subjectId : null,
        teacherId: _periodType == PeriodType.lesson ? _profesorSel!.id : null,
        isFifthModule: _quintoModulo,
        workshopGroupId: _grupoSel?.id,
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
    return _FormDialog(
      theme: theme,
      icon: Icons.event_note_outlined,
      titulo: 'Nuevo período',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(false),
      onSubmit: _submit,
      submitLabel: 'Crear período',
      children: [
        if (widget.grupos.isNotEmpty) ...[
          _DropdownGroup<WorkshopGroup?>(
            label: 'Alcance',
            value: _grupoSel,
            options: <WorkshopGroup?>[null, ...widget.grupos],
            itemLabel: (g) => g == null ? 'Curricular (todo el curso)' : 'Grupo ${g.name} (contraturno)',
            onChanged: (v) => setState(() => _grupoSel = v),
          ),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(child: _DropdownGroup<int>(
            label: 'Día', value: _dayOfWeek, options: const [1, 2, 3, 4, 5, 6, 7],
            hint: 'Día', itemLabel: _diaLabel, onChanged: (v) => setState(() => _dayOfWeek = v),
          )),
          const SizedBox(width: 16),
          Expanded(child: _DropdownGroup<ShiftType>(
            label: 'Turno', value: _shift, options: ShiftType.values,
            itemLabel: shiftTypeLabel, onChanged: (v) => setState(() => _shift = v!),
          )),
        ]),
        const SizedBox(height: 16),
        _DropdownGroup<PeriodType>(
          label: 'Tipo de período',
          value: _periodType,
          options: PeriodType.values,
          itemLabel: periodTypeLabel,
          onChanged: (v) => setState(() {
            _periodType = v!;
            if (_periodType != PeriodType.lesson) {
              _materiaSel = null;
              _profesorSel = null;
            }
          }),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _TimeButtonField(label: 'Hora de inicio', value: _start, onTap: _pickStart)),
          const SizedBox(width: 16),
          Expanded(child: _TimeButtonField(label: 'Hora de fin', value: _end, onTap: _pickEnd)),
        ]),
        if (_periodType == PeriodType.lesson) ...[
          const SizedBox(height: 16),
          _DropdownGroup<SubjectTeacherAssignment>(
            label: 'Materia',
            value: _materiaSel,
            options: widget.materias,
            hint: 'Materia',
            itemLabel: (m) => '${m.subjectName} (${m.teacherName})',
            onChanged: _onMateriaChanged,
          ),
          const SizedBox(height: 16),
          _DropdownGroup<Teacher>(
            label: 'Profesor a cargo (cambiá acá si es un reemplazo puntual)',
            value: _profesorSel,
            options: widget.profesores,
            hint: 'Profesor',
            itemLabel: (p) => p.fullName,
            onChanged: (v) => setState(() => _profesorSel = v),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Checkbox(value: _quintoModulo, onChanged: (v) => setState(() => _quintoModulo = v ?? false),
              activeColor: AAMColors.accent),
          Text('Este día tiene 5to módulo', style: GoogleFonts.dmSans(fontSize: 13, color: theme.text)),
        ]),
      ],
    );
  }
}

// ─── Tab: Materias y profesores ─────────────────────────────────────────────
class _TabMaterias extends StatefulWidget {
  const _TabMaterias({required this.curso, required this.ds});
  final Course curso;
  final ApiDatasource ds;

  @override
  State<_TabMaterias> createState() => _TabMateriasState();
}

class _TabMateriasState extends State<_TabMaterias> {
  List<SubjectTeacherAssignment> _asignaciones = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.ds.getCourseSubjectTeachers(widget.curso.id);
      if (mounted) setState(() => _asignaciones = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar las materias del curso.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _asignar() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _AsignarMateriaForm(ds: widget.ds, courseId: widget.curso.id),
    );
    if (result == true) _cargar();
  }

  Future<void> _quitar(SubjectTeacherAssignment a) async {
    final ok = await _confirmarEliminacion(context,
        titulo: 'Quitar materia',
        mensaje: '¿Quitar "${a.subjectName}" del curso? El horario detallado que use esta materia dejará de tener profesor asignado.');
    if (!ok) return;
    try {
      await widget.ds.quitarCourseSubjectTeacher(widget.curso.id, a.subjectId);
      _cargar();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo quitar la materia.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    if (_loading) return const AAMLoadingScreen();
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_error != null) ...[
          Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.danger)),
          const SizedBox(height: 16),
        ],
        Text('Materias del curso', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text)),
        const SizedBox(height: 16),
        ..._asignaciones.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MateriaRow(asignacion: a, theme: theme, onDelete: () => _quitar(a)),
            )),
        _DashedAddRow(label: 'Asignar materia', onTap: _asignar),
      ]),
    );
  }
}

class _MateriaRow extends StatelessWidget {
  const _MateriaRow({required this.asignacion, required this.theme, required this.onDelete});
  final SubjectTeacherAssignment asignacion;
  final AAMTheme theme;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final contacto = [
      if (asignacion.teacherEmail != null && asignacion.teacherEmail!.isNotEmpty) asignacion.teacherEmail,
      if (asignacion.teacherPhone != null && asignacion.teacherPhone!.isNotEmpty) asignacion.teacherPhone,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _InitialsAvatar(text: asignacion.subjectName, color: avatarColorFor(asignacion.subjectName), size: 36),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asignacion.subjectName, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text)),
          Text('Prof. ${asignacion.teacherName}', style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
        ])),
        Text(contacto, style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec), textAlign: TextAlign.right),
        const SizedBox(width: 12),
        GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_outline, size: 18, color: AAMColors.danger)),
      ]),
    );
  }
}

class _AsignarMateriaForm extends StatefulWidget {
  const _AsignarMateriaForm({required this.ds, required this.courseId});
  final ApiDatasource ds;
  final String courseId;

  @override
  State<_AsignarMateriaForm> createState() => _AsignarMateriaFormState();
}

class _AsignarMateriaFormState extends State<_AsignarMateriaForm> {
  List<Subject> _materias = [];
  List<Teacher> _profesores = [];
  Subject? _materiaSel;
  Teacher? _profesorSel;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([widget.ds.getSubjects(), widget.ds.getTeachers()]);
      if (!mounted) return;
      setState(() {
        _materias = results[0] as List<Subject>;
        _profesores = results[1] as List<Teacher>;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar las materias/profesores.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _nuevaMateria() async {
    final nombre = await _pedirTexto(context, titulo: 'Nueva materia', hint: 'Nombre de la materia');
    if (nombre == null || nombre.trim().isEmpty) return;
    try {
      final materia = await widget.ds.crearSubject(nombre.trim());
      if (!mounted) return;
      setState(() {
        _materias = [..._materias, materia];
        _materiaSel = materia;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo crear la materia.');
    }
  }

  Future<void> _nuevoProfesor() async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => const _NuevoProfesorDialog(),
    );
    if (datos == null || (datos['fullName'] ?? '').trim().isEmpty) return;
    try {
      final profesor = await widget.ds.crearTeacher(
        fullName: datos['fullName']!.trim(),
        email: datos['email'],
        phone: datos['phone'],
      );
      if (!mounted) return;
      setState(() {
        _profesores = [..._profesores, profesor];
        _profesorSel = profesor;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo crear el profesor.');
    }
  }

  Future<void> _submit() async {
    if (_materiaSel == null) {
      setState(() => _error = 'Seleccioná la materia.');
      return;
    }
    if (_profesorSel == null) {
      setState(() => _error = 'Seleccioná el profesor.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ds.asignarCourseSubjectTeacher(
        courseId: widget.courseId,
        subjectId: _materiaSel!.id,
        teacherId: _profesorSel!.id,
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
    if (_loading) {
      return const Dialog(child: Padding(padding: EdgeInsets.all(40), child: AAMLoadingScreen()));
    }
    return _FormDialog(
      theme: theme,
      icon: Icons.menu_book_outlined,
      titulo: 'Asignar materia',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(false),
      onSubmit: _submit,
      submitLabel: 'Asignar',
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _DropdownGroup<Subject>(
            label: 'Materia', value: _materiaSel, options: _materias,
            hint: 'Materia', itemLabel: (m) => m.name, onChanged: (v) => setState(() => _materiaSel = v),
          )),
          const SizedBox(width: 8),
          IconButton(onPressed: _nuevaMateria, icon: const Icon(Icons.add_circle_outline, color: AAMColors.accent), tooltip: 'Nueva materia'),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _DropdownGroup<Teacher>(
            label: 'Profesor', value: _profesorSel, options: _profesores,
            hint: 'Profesor', itemLabel: (t) => t.fullName, onChanged: (v) => setState(() => _profesorSel = v),
          )),
          const SizedBox(width: 8),
          IconButton(onPressed: _nuevoProfesor, icon: const Icon(Icons.add_circle_outline, color: AAMColors.accent), tooltip: 'Nuevo profesor'),
        ]),
      ],
    );
  }
}

class _NuevoProfesorDialog extends StatefulWidget {
  const _NuevoProfesorDialog();

  @override
  State<_NuevoProfesorDialog> createState() => _NuevoProfesorDialogState();
}

class _NuevoProfesorDialogState extends State<_NuevoProfesorDialog> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return _FormDialog(
      theme: theme,
      icon: Icons.person_add_alt_outlined,
      titulo: 'Nuevo profesor',
      error: _error,
      submitting: false,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: () {
        if (_nombreCtrl.text.trim().isEmpty) {
          setState(() => _error = 'Ingresá el nombre del profesor.');
          return;
        }
        Navigator.of(context).pop({
          'fullName': _nombreCtrl.text,
          'email': _emailCtrl.text,
          'phone': _telefonoCtrl.text,
        });
      },
      submitLabel: 'Crear profesor',
      children: [
        _FieldGroup(label: 'Nombre completo', child: _textInput(_nombreCtrl, 'Ej: Juan Pérez')),
        const SizedBox(height: 16),
        _FieldGroup(label: 'Email (opcional)', child: _textInput(_emailCtrl, 'Ej: juan.perez@mail.com', keyboard: TextInputType.emailAddress)),
        const SizedBox(height: 16),
        _FieldGroup(label: 'Teléfono (opcional)', child: _textInput(_telefonoCtrl, 'Ej: 11-2345-6789', keyboard: TextInputType.phone)),
      ],
    );
  }
}

// ─── Tab: Preceptores ────────────────────────────────────────────────────────
class _TabPreceptores extends StatefulWidget {
  const _TabPreceptores({required this.curso, required this.ds});
  final Course curso;
  final ApiDatasource ds;

  @override
  State<_TabPreceptores> createState() => _TabPreceptoresState();
}

class _TabPreceptoresState extends State<_TabPreceptores> {
  List<ShiftType> _turnosDelCurso = [];
  List<CoursePreceptor> _permanentes = [];
  List<CoursePreceptorTempAssignment> _temporales = [];
  List<User> _usuarios = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final timeSlotRepo = TimeSlotRepositoryImpl(widget.ds);
      final results = await Future.wait([
        timeSlotRepo.getTimeSlotsByCourse(widget.curso.id),
        widget.ds.getCoursePreceptors(widget.curso.id),
        widget.ds.getCoursePreceptorTempAssignments(widget.curso.id),
        widget.ds.getUsers(),
      ]);
      if (!mounted) return;
      final slots = results[0] as List<TimeSlot>;
      setState(() {
        _turnosDelCurso = slots.map((s) => s.shift).toSet().toList();
        _permanentes = results[1] as List<CoursePreceptor>;
        _temporales = results[2] as List<CoursePreceptorTempAssignment>;
        _usuarios = results[3] as List<User>;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los preceptores del curso.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<User> get _preceptoresDisponibles => _usuarios.where((u) => u.role == UserRole.preceptor).toList();

  Future<void> _asignarPermanente(ShiftType shift) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _AsignarPreceptorForm(
        ds: widget.ds,
        courseId: widget.curso.id,
        shift: shift,
        preceptores: _preceptoresDisponibles,
      ),
    );
    if (result == true) _cargar();
  }

  Future<void> _quitarPermanente(ShiftType shift) async {
    final ok = await _confirmarEliminacion(context,
        titulo: 'Quitar preceptor',
        mensaje: '¿Quitar el preceptor a cargo del turno ${shiftTypeLabel(shift)}?');
    if (!ok) return;
    try {
      await widget.ds.quitarCoursePreceptor(widget.curso.id, shift);
      _cargar();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo quitar el preceptor.');
    }
  }

  Future<void> _agregarTemporal() async {
    if (_turnosDelCurso.isEmpty) {
      setState(() => _error = 'Cargá el turno principal del curso (pestaña Horario) antes de asignar un reemplazo.');
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevoReemplazoForm(
        ds: widget.ds,
        courseId: widget.curso.id,
        turnos: _turnosDelCurso,
        preceptores: _preceptoresDisponibles,
        usuarios: _usuarios,
      ),
    );
    if (result == true) _cargar();
  }

  Future<void> _eliminarTemporal(CoursePreceptorTempAssignment t) async {
    final ok = await _confirmarEliminacion(context,
        titulo: 'Eliminar reemplazo temporal',
        mensaje: '¿Eliminar el reemplazo de ${t.preceptorName} (${t.startDate.day}/${t.startDate.month}–${t.endDate.day}/${t.endDate.month})?');
    if (!ok) return;
    try {
      await widget.ds.eliminarCoursePreceptorTempAssignment(widget.curso.id, t.id);
      _cargar();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo eliminar el reemplazo temporal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    if (_loading) return const AAMLoadingScreen();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_error != null) ...[
          Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.danger)),
          const SizedBox(height: 16),
        ],
        Text('PERMANENTE POR TURNO', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: theme.textSec, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        if (_turnosDelCurso.isEmpty)
          _EmptyRow(theme: theme, mensaje: 'Cargá el turno principal del curso para poder asignar preceptores.')
        else
          ..._turnosDelCurso.map((shift) {
            CoursePreceptor? actual;
            try {
              actual = _permanentes.firstWhere((p) => p.shift == shift);
            } catch (_) {
              actual = null;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PreceptorPermanenteRow(
                shift: shift,
                actual: actual,
                theme: theme,
                onAsignar: () => _asignarPermanente(shift),
                onQuitar: actual == null ? null : () => _quitarPermanente(shift),
              ),
            );
          }),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: Text('REEMPLAZOS TEMPORALES', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: theme.textSec, letterSpacing: 0.6))),
          _DashedButton(label: 'Agregar', onTap: _agregarTemporal),
        ]),
        const SizedBox(height: 10),
        if (_temporales.isEmpty)
          _EmptyRow(theme: theme, mensaje: 'Sin reemplazos temporales cargados.')
        else
          ..._temporales.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReemplazoRow(asignacion: t, theme: theme, onDelete: () => _eliminarTemporal(t)),
              )),
      ]),
    );
  }
}

class _PreceptorPermanenteRow extends StatelessWidget {
  const _PreceptorPermanenteRow({required this.shift, required this.actual, required this.theme, required this.onAsignar, this.onQuitar});
  final ShiftType shift;
  final CoursePreceptor? actual;
  final AAMTheme theme;
  final VoidCallback onAsignar;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _InitialsAvatar(text: actual?.preceptorName ?? '?', color: avatarColorFor(actual?.preceptorName ?? shift.name), size: 36),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(actual?.preceptorName ?? 'Sin asignar',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: actual == null ? theme.textSec : theme.text)),
          Text(actual == null ? 'Sin preceptor a cargo' : 'A cargo desde el inicio del año lectivo',
              style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
        ])),
        AAMBadge(label: shiftTypeLabel(shift), color: AAMColors.info),
        const SizedBox(width: 12),
        GestureDetector(onTap: onAsignar, child: Icon(actual == null ? Icons.add_circle_outline : Icons.edit_outlined, size: 18, color: AAMColors.accent)),
        if (onQuitar != null) ...[
          const SizedBox(width: 10),
          GestureDetector(onTap: onQuitar, child: const Icon(Icons.delete_outline, size: 18, color: AAMColors.danger)),
        ],
      ]),
    );
  }
}

class _ReemplazoRow extends StatelessWidget {
  const _ReemplazoRow({required this.asignacion, required this.theme, required this.onDelete});
  final CoursePreceptorTempAssignment asignacion;
  final AAMTheme theme;
  final VoidCallback onDelete;

  String _fecha(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_mes(d.month)}';
  String _mes(int m) => const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'][m - 1];

  @override
  Widget build(BuildContext context) {
    final total = addOneCalendarMonth(asignacion.startDate).difference(asignacion.startDate).inMinutes;
    final elapsed = asignacion.endDate.difference(asignacion.startDate).inMinutes;
    final progreso = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _InitialsAvatar(text: asignacion.preceptorName, color: avatarColorFor(asignacion.preceptorName), size: 36),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(asignacion.preceptorName, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text)),
            Text(
              '${asignacion.reason?.isNotEmpty == true ? '${asignacion.reason} · ' : ''}${shiftTypeLabel(asignacion.shift)}',
              style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec),
            ),
          ])),
          GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_outline, size: 18, color: AAMColors.danger)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text(_fecha(asignacion.startDate), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: theme.textSec)),
          const SizedBox(width: 8),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progreso, minHeight: 6, color: AAMColors.accent, backgroundColor: theme.borderCol),
          )),
          const SizedBox(width: 8),
          Text(_fecha(asignacion.endDate), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: theme.textSec)),
        ]),
        const SizedBox(height: 4),
        Center(child: Text('Máximo permitido: 1 mes', style: GoogleFonts.dmSans(fontSize: 10, color: theme.textSec))),
      ]),
    );
  }
}

class _AsignarPreceptorForm extends StatefulWidget {
  const _AsignarPreceptorForm({required this.ds, required this.courseId, required this.shift, required this.preceptores});
  final ApiDatasource ds;
  final String courseId;
  final ShiftType shift;
  final List<User> preceptores;

  @override
  State<_AsignarPreceptorForm> createState() => _AsignarPreceptorFormState();
}

class _AsignarPreceptorFormState extends State<_AsignarPreceptorForm> {
  User? _preceptorSel;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_preceptorSel == null) {
      setState(() => _error = 'Seleccioná el preceptor.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ds.asignarCoursePreceptor(courseId: widget.courseId, shift: widget.shift, preceptorId: _preceptorSel!.id);
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
    return _FormDialog(
      theme: theme,
      icon: Icons.badge_outlined,
      titulo: 'Preceptor a cargo — ${shiftTypeLabel(widget.shift)}',
      error: _error,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(false),
      onSubmit: _submit,
      submitLabel: 'Asignar',
      children: [
        _DropdownGroup<User>(
          label: 'Preceptor',
          value: _preceptorSel,
          options: widget.preceptores,
          hint: widget.preceptores.isEmpty ? 'No hay preceptores cargados en Usuarios' : 'Preceptor',
          itemLabel: (u) => u.fullName,
          onChanged: (v) => setState(() => _preceptorSel = v),
        ),
      ],
    );
  }
}

class _NuevoReemplazoForm extends StatefulWidget {
  const _NuevoReemplazoForm({required this.ds, required this.courseId, required this.turnos, required this.preceptores, required this.usuarios});
  final ApiDatasource ds;
  final String courseId;
  final List<ShiftType> turnos;
  final List<User> preceptores;
  final List<User> usuarios;

  @override
  State<_NuevoReemplazoForm> createState() => _NuevoReemplazoFormState();
}

class _NuevoReemplazoFormState extends State<_NuevoReemplazoForm> {
  ShiftType? _shift;
  User? _preceptorSel;
  User? _registradoPor;
  DateTime? _start;
  DateTime? _end;
  final _motivoCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.turnos.length == 1) _shift = widget.turnos.first;
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  DateTime? get _maxEnd => _start == null ? null : addOneCalendarMonth(_start!);

  String? get _rangoError {
    if (_start == null || _end == null) return null;
    if (_end!.isBefore(_start!)) return 'La fecha de fin no puede ser anterior a la de inicio.';
    if (_end!.isAfter(_maxEnd!)) {
      return 'El reemplazo no puede superar 1 mes. Fecha límite: ${_maxEnd!.day.toString().padLeft(2, '0')}/${_maxEnd!.month.toString().padLeft(2, '0')}/${_maxEnd!.year}.';
    }
    return null;
  }

  Future<void> _pickStart() async {
    final d = await _pickDate(context, initial: _start);
    if (d == null) return;
    setState(() {
      _start = d;
      if (_end != null && (_end!.isBefore(d) || _end!.isAfter(addOneCalendarMonth(d)))) _end = null;
    });
  }

  Future<void> _pickEnd() async {
    if (_start == null) {
      setState(() => _error = 'Seleccioná primero la fecha de inicio.');
      return;
    }
    final d = await _pickDate(context, initial: _end ?? _start, firstDate: _start, lastDate: addOneCalendarMonth(_start!));
    if (d != null) setState(() => _end = d);
  }

  Future<void> _submit() async {
    if (_shift == null) {
      setState(() => _error = 'Seleccioná el turno.');
      return;
    }
    if (_preceptorSel == null) {
      setState(() => _error = 'Seleccioná el preceptor reemplazante.');
      return;
    }
    if (_start == null || _end == null) {
      setState(() => _error = 'Seleccioná el rango de fechas.');
      return;
    }
    if (_rangoError != null) {
      setState(() => _error = _rangoError);
      return;
    }
    if (_registradoPor == null) {
      setState(() => _error = 'Seleccioná quién registra esta asignación.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ds.crearCoursePreceptorTempAssignment(
        courseId: widget.courseId,
        shift: _shift!,
        preceptorId: _preceptorSel!.id,
        startDate: _start!,
        endDate: _end!,
        reason: _motivoCtrl.text.trim().isEmpty ? null : _motivoCtrl.text.trim(),
        createdByUserId: _registradoPor!.id,
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
    return _FormDialog(
      theme: theme,
      icon: Icons.event_available_outlined,
      titulo: 'Reemplazo temporal',
      error: _error ?? _rangoError,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(false),
      onSubmit: _submit,
      submitLabel: 'Crear reemplazo',
      children: [
        _DropdownGroup<ShiftType>(
          label: 'Turno', value: _shift, options: widget.turnos,
          hint: 'Turno', itemLabel: shiftTypeLabel, onChanged: (v) => setState(() => _shift = v),
        ),
        const SizedBox(height: 16),
        _DropdownGroup<User>(
          label: 'Preceptor reemplazante', value: _preceptorSel, options: widget.preceptores,
          hint: 'Preceptor', itemLabel: (u) => u.fullName, onChanged: (v) => setState(() => _preceptorSel = v),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _DateButtonField(label: 'Desde', value: _start, onTap: _pickStart)),
          const SizedBox(width: 16),
          Expanded(child: _DateButtonField(label: 'Hasta', value: _end, onTap: _pickEnd)),
        ]),
        const SizedBox(height: 6),
        Text('Máximo 1 mes por reemplazo.', style: GoogleFonts.dmSans(fontSize: 11, color: theme.textSec)),
        const SizedBox(height: 16),
        _FieldGroup(label: 'Motivo (opcional)', child: _textInput(_motivoCtrl, 'Ej: Licencia médica')),
        const SizedBox(height: 16),
        _DropdownGroup<User>(
          label: 'Registrado por', value: _registradoPor, options: widget.usuarios,
          hint: 'Quién registra esta asignación', itemLabel: (u) => u.fullName, onChanged: (v) => setState(() => _registradoPor = v),
        ),
      ],
    );
  }
}

// ─── Helpers compartidos ─────────────────────────────────────────────────────

const List<String> _diasLabels = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
String _diaLabel(int d) => (d >= 1 && d <= 7) ? _diasLabels[d - 1] : 'Día $d';

Future<ClockTime?> _pickTime(BuildContext context, ClockTime? initial) async {
  final t = await showTimePicker(
    context: context,
    initialTime: initial != null ? TimeOfDay(hour: initial.hour, minute: initial.minute) : const TimeOfDay(hour: 8, minute: 0),
  );
  if (t == null) return null;
  return ClockTime(t.hour, t.minute);
}

Future<DateTime?> _pickDate(BuildContext context, {DateTime? initial, DateTime? firstDate, DateTime? lastDate}) {
  return showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: firstDate ?? DateTime(2000),
    lastDate: lastDate ?? DateTime(2100),
  );
}

Future<bool> _confirmarEliminacion(BuildContext context, {required String titulo, required String mensaje}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
    builder: (_) => _ConfirmDialog(titulo: titulo, mensaje: mensaje),
  );
  return result == true;
}

Future<String?> _pedirTexto(BuildContext context, {required String titulo, required String hint}) async {
  final ctrl = TextEditingController();
  final theme = AAMTheme();
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
          const SizedBox(height: 14),
          _textInput(ctrl, hint),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)))),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(ctrl.text),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('Crear', style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.white)))),
            )),
          ]),
        ]),
      ),
    ),
  );
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

class _DropdownGroup<T> extends StatelessWidget {
  const _DropdownGroup({required this.label, required this.value, required this.options, required this.onChanged, this.hint, this.itemLabel});
  final String label;
  final T? value;
  final List<T> options;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String Function(T)? itemLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    final habilitado = onChanged != null && options.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
        child: DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          isExpanded: true,
          hint: Text(hint ?? 'Seleccionar', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
          style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(itemLabel != null ? itemLabel!(o) : o.toString()))).toList(),
          onChanged: habilitado ? onChanged : null,
        ),
      ),
    ]);
  }
}

class _TimeButtonField extends StatelessWidget {
  const _TimeButtonField({required this.label, required this.value, required this.onTap});
  final String label;
  final ClockTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return _FieldGroup(label: label, child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.access_time, size: 16, color: theme.textSec),
          const SizedBox(width: 8),
          Text(value?.label ?? 'Seleccionar', style: GoogleFonts.dmSans(fontSize: 14, color: value == null ? theme.textSec : theme.text)),
        ]),
      ),
    ));
  }
}

class _DateButtonField extends StatelessWidget {
  const _DateButtonField({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    final texto = value == null
        ? 'Seleccionar'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return _FieldGroup(label: label, child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: theme.textSec),
          const SizedBox(width: 8),
          Text(texto, style: GoogleFonts.dmSans(fontSize: 14, color: value == null ? theme.textSec : theme.text)),
        ]),
      ),
    ));
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap, required this.theme});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AAMColors.primary : Colors.transparent,
          border: Border.all(color: selected ? AAMColors.primary : theme.borderCol),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? AAMColors.white : theme.textSec,
        )),
      ),
    );
  }
}

// ─── Avatar de iniciales (paleta reciclada de AAMColors, sin hex nuevos) ────
const List<Color> _avatarPalette = [
  AAMColors.accent, AAMColors.primary, AAMColors.violet,
  AAMColors.teal, AAMColors.indigo, AAMColors.slate,
];
Color avatarColorFor(String seed) => _avatarPalette[seed.hashCode.abs() % _avatarPalette.length];

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.text, required this.color, this.size = 40});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(text.isEmpty ? '?' : text[0].toUpperCase(),
          style: GoogleFonts.dmSans(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: AAMColors.white)),
    );
  }
}

// ─── Borde punteado (afordancia de "agregar", según mockups) ───────────────
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final dashPath = Path();
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashPath.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        distance = next + dashSpace;
      }
    }
    canvas.drawPath(dashPath, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// Pill compacta con borde punteado, para acciones "+ Agregar" en headers.
class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: CustomPaint(
          painter: _DashedRRectPainter(color: AAMColors.accent, radius: 999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add, size: 14, color: AAMColors.accent),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AAMColors.accent)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Fila de ancho completo con borde punteado, para cerrar una lista con la
/// acción de agregar (en vez de un botón arriba) — según materias_profesores.jpg.
class _DashedAddRow extends StatelessWidget {
  const _DashedAddRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: CustomPaint(
          painter: _DashedRRectPainter(color: AAMColors.accent, radius: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add, size: 16, color: AAMColors.accent),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AAMColors.accent)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.theme, required this.title, required this.children, this.action});
  final AAMTheme theme;
  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text))),
          if (action != null) action!,
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.theme, required this.mensaje});
  final AAMTheme theme;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(mensaje, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.titulo, required this.mensaje});
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
          const SizedBox(height: 10),
          Text(mensaje, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)))),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: AAMColors.danger, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('Eliminar', style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.white)))),
            )),
          ]),
        ]),
      ),
    );
  }
}

/// Layout genérico de un diálogo de formulario (título + campos + acciones),
/// usado por todos los formularios de esta pantalla para no repetir el
/// mismo Container/Dialog/Row de botones una y otra vez.
class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.theme,
    required this.icon,
    required this.titulo,
    required this.children,
    required this.onCancel,
    required this.onSubmit,
    required this.submitLabel,
    this.error,
    this.submitting = false,
  });

  final AAMTheme theme;
  final IconData icon;
  final String titulo;
  final List<Widget> children;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String submitLabel;
  final String? error;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8))],
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AAMColors.primary, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AAMColors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo, style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: theme.text))),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.close, size: 16, color: theme.textSec),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            ...children,
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.danger)),
            ],
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec))),
                ),
              )),
              const SizedBox(width: 14),
              Expanded(child: GestureDetector(
                onTap: submitting ? null : onSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: submitting ? AAMColors.accent.withAlpha((0.6 * 255).round()) : AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                      : Text(submitLabel, style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.white))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}
