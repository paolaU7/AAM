import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/workshop_group.dart';
import '../../domain/usecases/get_students.dart';
import '../../domain/usecases/create_student.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../../infrastructure/repositories/student_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class AlumnosScreen extends StatefulWidget {
  const AlumnosScreen({super.key});

  @override
  State<AlumnosScreen> createState() => _AlumnosScreenState();
}

class _AlumnosScreenState extends State<AlumnosScreen> {
  late final StudentRepositoryImpl _repo;
  late final GetStudents _getStudents;
  late final CreateStudent _createStudent;
  late Future<List<Student>> _future;

  String _searchQuery = '';
  String _filterCurso = 'Todos';
  String _filterEstado = 'Todos';

  @override
  void initState() {
    super.initState();
    final api = ApiDatasource();
    _repo = StudentRepositoryImpl(api);
    _getStudents = GetStudents(_repo);
    _createStudent = CreateStudent(_repo);
    _future = _getStudents();
  }

  void _refresh() => setState(() => _future = _getStudents());

  Future<void> _abrirNuevoAlumno() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevoAlumnoForm(repo: _repo, createStudent: _createStudent),
    );
    if (result == true) _refresh();
  }

  Future<void> _abrirDetalle(Student alumno) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _AlumnoDetalleModal(alumno: alumno),
    );
  }

  Future<void> _abrirEdicion(Student alumno) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _EditarAlumnoModal(
        alumno: alumno,
        onSave: (updated) async {
          await _repo.actualizarAlumno(updated);
        },
      ),
    );
    if (result == true) _refresh();
  }

  List<Student> _applyFilters(List<Student> all) {
    return all.where((a) {
      final matchSearch = _searchQuery.isEmpty ||
          a.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.dni.contains(_searchQuery) ||
          a.curso.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCurso = _filterCurso == 'Todos' || a.curso == _filterCurso;
      final matchEstado = switch (_filterEstado) {
        'Todos' => true,
        'Regular' => a.estadoRegularidad == EstadoRegularidad.regular,
        'Irregular' => a.estadoRegularidad == EstadoRegularidad.irregular,
        'En riesgo' => a.estadoRegularidad == EstadoRegularidad.enRiesgo,
        'Recursante' => a.recursante,
        _ => true,
      };
      return matchSearch && matchCurso && matchEstado;
    }).toList();
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
          title: 'Alumnos',
          actions: [
            AAMButton(label: 'Nuevo alumno', icon: Icons.add, onPressed: _abrirNuevoAlumno),
            const SizedBox(width: 8),
            const AAMButton(label: 'Importar Excel', icon: Icons.upload_file_outlined, outlined: true),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Student>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const AAMLoadingScreen();
              }
              if (snap.hasError) {
                return AAMErrorWidget(
                  message: 'Error al cargar alumnos',
                  onRetry: () => setState(() => _future = _getStudents()),
                );
              }

              final alumnos  = _applyFilters(snap.data!);
              final cursoOpts = ['Todos', ...snap.data!.map((a) => a.curso).toSet().toList()..sort()];

              return Padding(
                padding: const EdgeInsets.all(32),
                child: _buildContent(theme, cursoOpts, snap.data!.length, alumnos),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContent(AAMTheme theme, List<String> cursoOpts, int totalAlumnos, List<Student> alumnos) {
    return Column(children: [
      _buildFilters(cursoOpts, totalAlumnos, alumnos.length, theme),
      const SizedBox(height: 24),
      Expanded(child: _buildTable(alumnos, theme)),
    ]);
  }

  Widget _buildFilters(List<String> cursos, int total, int filtered, AAMTheme theme) {
    return Row(children: [
      Expanded(
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: theme.card,
            border: Border.all(color: theme.borderCol),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, DNI o curso...',
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec),
              prefixIcon: Icon(Icons.search, size: 18, color: theme.textSec),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: theme.card,
          border: Border.all(color: theme.borderCol),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButton<String>(
          value: _filterCurso,
          underline: const SizedBox.shrink(),
          style: GoogleFonts.dmSans(fontSize: 13, color: theme.text),
          items: cursos.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _filterCurso = v ?? 'Todos'),
        ),
      ),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: theme.card,
          border: Border.all(color: theme.borderCol),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButton<String>(
          value: _filterEstado,
          underline: const SizedBox.shrink(),
          style: GoogleFonts.dmSans(fontSize: 13, color: theme.text),
          items: const [
            'Todos',
            'Regular',
            'Irregular',
            'En riesgo',
            'Recursante',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _filterEstado = v ?? 'Todos'),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        '$filtered de $total alumnos',
        style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
      ),
    ]);
  }

  Widget _buildTable(List<Student> alumnos, AAMTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const AAMTableHeader(columns: [
          ('Alumno',       3),
          ('Curso',        2),
          ('DNI',          2),
          ('Asistencia',   2),
          ('Estado',       2),
          ('',             1),
        ]),
        Expanded(
          child: alumnos.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_add_outlined, size: 44, color: theme.borderCol),
                    const SizedBox(height: 14),
                    Text('No hay alumnos cargados aún',
                      style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
                    const SizedBox(height: 8),
                    AAMButton(label: 'Agregar primer alumno', onPressed: _abrirNuevoAlumno),
                  ],
                ))
              : ListView.builder(
                  itemCount: alumnos.length,
                  itemBuilder: (ctx, i) => _AlumnoRow(
                    alumno: alumnos[i],
                    theme: theme,
                    onVerDetalle: () => _abrirDetalle(alumnos[i]),
                    onEditar: () => _abrirEdicion(alumnos[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ─── Fila de alumno ───────────────────────────────────────────────────────────
class _AlumnoRow extends StatefulWidget {
  const _AlumnoRow({
    required this.alumno,
    required this.theme,
    required this.onVerDetalle,
    required this.onEditar,
  });

  final Student alumno;
  final AAMTheme theme;
  final VoidCallback onVerDetalle;
  final VoidCallback onEditar;

  @override
  State<_AlumnoRow> createState() => _AlumnoRowState();
}

class _AlumnoRowState extends State<_AlumnoRow> {
  bool _hovered = false;

  Color get _asistColor {
    final pct = widget.alumno.porcentajeAsistencia;
    if (pct < 65) return AAMColors.highlight;
    if (pct < 75) return AAMColors.warning;
    return AAMColors.success;
  }

  (String, Color) get _estadoBadge => switch (widget.alumno.estadoRegularidad) {
    EstadoRegularidad.regular    => ('Regular',    AAMColors.success),
    EstadoRegularidad.irregular  => ('Irregular',  AAMColors.warning),
    EstadoRegularidad.enRiesgo   => ('En riesgo',  AAMColors.highlight),
  };

  @override
  Widget build(BuildContext context) {
    final a = widget.alumno;
    final (estadoLabel, estadoColor) = _estadoBadge;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onVerDetalle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? widget.theme.surfaceCol : widget.theme.card,
            border: Border(bottom: BorderSide(color: widget.theme.borderCol, width: 1)),
          ),
          child: Row(children: [
            // Alumno
            Expanded(flex: 3, child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AAMColors.mint,
                child: Text(a.apellido.substring(0, 1),
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: widget.theme.text)),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.nombreCompleto,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text)),
                if (a.recursante)
                  Row(children: [
                    Icon(Icons.repeat_outlined, size: 14, color: AAMColors.accent),
                    const SizedBox(width: 4),
                    Text('Recursante', style: GoogleFonts.dmSans(fontSize: 10, color: AAMColors.accent)),
                  ]),
              ]),
            ])),
            // Curso
            Expanded(flex: 2, child: Text(a.curso,
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.text))),
            // DNI
            Expanded(flex: 2, child: Text(a.dni,
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
            // Asistencia
            Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.porcentajeAsistencia.toStringAsFixed(1)}%',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _asistColor)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: a.porcentajeAsistencia / 100,
                  minHeight: 6,
                  color: _asistColor,
                  backgroundColor: widget.theme.borderCol,
                ),
              ),
            ])),
            // Estado
            Expanded(flex: 2, child: AAMBadge(label: estadoLabel, color: estadoColor)),
            // Acciones
            Expanded(flex: 1, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(
                icon: Icons.visibility_outlined,
                color: widget.theme.text,
                tooltip: 'Ver detalle',
                onTap: widget.onVerDetalle,
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                icon: Icons.edit_outlined,
                color: AAMColors.accent,
                tooltip: 'Editar alumno',
                onTap: widget.onEditar,
              ),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withAlpha((0.16 * 255).round()) : widget.color.withAlpha((0.08 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Tooltip(
            message: widget.tooltip,
            child: Icon(widget.icon, size: 16, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _AlumnoDetalleModal extends StatelessWidget {
  const _AlumnoDetalleModal({required this.alumno});
  final Student alumno;

  @override
  Widget build(BuildContext context) {
    final (estadoLabel, estadoColor) = switch (alumno.estadoRegularidad) {
      EstadoRegularidad.regular => ('Regular', AAMColors.success),
      EstadoRegularidad.irregular => ('Irregular', AAMColors.warning),
      EstadoRegularidad.enRiesgo => ('En riesgo', AAMColors.highlight),
    };

    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AAMColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.person, size: 18, color: AAMColors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(alumno.nombreCompleto, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text)),
                  const SizedBox(height: 4),
                  Text(alumno.curso,
                    style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close, size: 16, color: theme.textSec),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Text('Asistencia', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textSec)),
              const SizedBox(height: 10),
              Row(children: [
                Text('${alumno.porcentajeAsistencia.toStringAsFixed(1)}%',
                  style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, color: estadoColor)),
                const SizedBox(width: 14),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: alumno.porcentajeAsistencia / 100,
                    minHeight: 10,
                    color: estadoColor,
                    backgroundColor: theme.borderCol,
                  ),
                )),
              ]),
              const SizedBox(height: 20),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _DetalleChip(label: 'DNI', value: alumno.dni),
                _DetalleChip(label: 'Curso', value: alumno.curso),
                if (alumno.taller != null)
                  _DetalleChip(label: 'Taller', value: alumno.taller!, color: AAMColors.accent),
                _DetalleChip(label: 'Estado', value: estadoLabel, color: estadoColor),
                if (alumno.recursante)
                  _DetalleChip(label: 'Recursante', value: 'Sí', color: AAMColors.accent),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Avance del período', style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: alumno.porcentajeAsistencia / 100,
                    minHeight: 8,
                    color: estadoColor,
                    backgroundColor: theme.borderCol,
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Alta de alumno (cascada: año lectivo → año de cursada → división → taller) ───
class _NuevoAlumnoForm extends StatefulWidget {
  const _NuevoAlumnoForm({required this.repo, required this.createStudent});

  final StudentRepositoryImpl repo;
  final CreateStudent createStudent;

  @override
  State<_NuevoAlumnoForm> createState() => _NuevoAlumnoFormState();
}

class _NuevoAlumnoFormState extends State<_NuevoAlumnoForm> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();

  // `courses` no tiene catálogos propios (año lectivo/año de cursada/división
  // son 3 columnas numéricas con UNIQUE compuesto) — los selectores en
  // cascada se derivan de los cursos ya existentes. El grupo de taller es un
  // FK simple y opcional, scoped al curso ya resuelto.
  List<Course> _cursos = [];
  List<WorkshopGroup> _talleres = [];

  int? _anioLectivoSel;
  int? _anioCursadaSel;
  int? _divisionSel;
  WorkshopGroup? _tallerSel;

  bool _cursosLoading = true;
  bool _talleresLoading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _dniCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCursos() async {
    setState(() {
      _cursosLoading = true;
      _error = null;
    });
    try {
      final cs = await widget.repo.getCourses();
      if (!mounted) return;
      setState(() => _cursos = cs);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los cursos.');
    } finally {
      if (mounted) setState(() => _cursosLoading = false);
    }
  }

  List<int> get _aniosLectivos {
    final s = _cursos.map((c) => c.academicYear).toSet().toList()..sort();
    return s;
  }

  List<int> get _aniosCursada {
    if (_anioLectivoSel == null) return [];
    final s = _cursos
        .where((c) => c.academicYear == _anioLectivoSel)
        .map((c) => c.gradeYear)
        .toSet()
        .toList()
      ..sort();
    return s;
  }

  List<int> get _divisiones {
    if (_anioLectivoSel == null || _anioCursadaSel == null) return [];
    final s = _cursos
        .where((c) => c.academicYear == _anioLectivoSel && c.gradeYear == _anioCursadaSel)
        .map((c) => c.division)
        .toSet()
        .toList()
      ..sort();
    return s;
  }

  // El curso queda unívocamente identificado por las 3 dimensiones: el
  // UNIQUE de `courses` está sobre (academic_year, grade_year, division).
  Course? get _cursoResuelto {
    final a = _anioLectivoSel, g = _anioCursadaSel, d = _divisionSel;
    if (a == null || g == null || d == null) return null;
    try {
      return _cursos.firstWhere(
          (c) => c.academicYear == a && c.gradeYear == g && c.division == d);
    } catch (_) {
      return null;
    }
  }

  void _onAnioLectivoChanged(int? v) {
    setState(() {
      _anioLectivoSel = v;
      _anioCursadaSel = null;
      _divisionSel = null;
      _tallerSel = null;
      _talleres = [];
      _error = null;
    });
  }

  void _onAnioCursadaChanged(int? v) {
    setState(() {
      _anioCursadaSel = v;
      _divisionSel = null;
      _tallerSel = null;
      _talleres = [];
      _error = null;
    });
  }

  void _onDivisionChanged(int? v) {
    setState(() {
      _divisionSel = v;
      _tallerSel = null;
      _talleres = [];
      _error = null;
    });
    final curso = _cursoResuelto;
    if (curso != null) _cargarTalleres(curso);
  }

  // Los grupos de taller son una subdivisión interna de ESTE curso puntual
  // (no se comparten entre cursos) — recién se pueden pedir una vez resuelto.
  Future<void> _cargarTalleres(Course curso) async {
    setState(() => _talleresLoading = true);
    try {
      final ts = await widget.repo.getWorkshopGroupsByCourse(curso.id);
      if (!mounted || _cursoResuelto?.id != curso.id) return; // selección obsoleta
      setState(() => _talleres = ts);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los grupos de taller.');
    } finally {
      if (mounted) setState(() => _talleresLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_anioLectivoSel == null) {
      setState(() => _error = 'Seleccioná un año lectivo.');
      return;
    }
    if (_anioCursadaSel == null) {
      setState(() => _error = 'Seleccioná un año de cursada.');
      return;
    }
    if (_divisionSel == null) {
      setState(() => _error = 'Seleccioná una división.');
      return;
    }
    final curso = _cursoResuelto;
    if (curso == null) {
      setState(() => _error = 'No existe un curso para esa combinación de año y división.');
      return;
    }
    // El grupo de taller es obligatorio salvo que el curso directamente no
    // tenga ninguno cargado (no hay nada para elegir en ese caso).
    if (_tallerSel == null && _talleres.isNotEmpty) {
      setState(() => _error = 'Seleccioná un grupo de taller.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.createStudent.call(
        firstName: _nombreCtrl.text,
        lastName: _apellidoCtrl.text,
        nationalId: _dniCtrl.text,
        courseId: curso.id,
        workshopGroupId: _tallerSel?.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // Muestra el mensaje del backend (p.ej. DNI duplicado) o de validación.
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
                    child: const Icon(Icons.person_add_outlined, size: 18, color: AAMColors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Nuevo alumno',
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

                // 1) Año lectivo   ·   2) Año de cursada (habilitado al elegir año lectivo)
                Row(children: [
                  Expanded(child: _DropdownGroup<int>(
                    label: 'Año lectivo',
                    value: _anioLectivoSel,
                    options: _aniosLectivos,
                    hint: _cursosLoading ? 'Cargando...' : 'Año lectivo',
                    itemLabel: (a) => '$a',
                    onChanged: _cursosLoading ? null : _onAnioLectivoChanged,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _DropdownGroup<int>(
                    label: 'Año de cursada',
                    value: _anioCursadaSel,
                    options: _aniosCursada,
                    hint: _anioLectivoSel == null
                        ? 'Elegí un año lectivo'
                        : 'Año de cursada',
                    itemLabel: gradeYearOrdinal,
                    onChanged: _anioLectivoSel == null ? null : _onAnioCursadaChanged,
                  )),
                ]),
                const SizedBox(height: 16),
                // 3) División
                _DropdownGroup<int>(
                  label: 'División',
                  value: _divisionSel,
                  options: _divisiones,
                  hint: _anioCursadaSel == null ? 'Elegí un año de cursada' : 'División',
                  itemLabel: divisionOrdinal,
                  onChanged: _anioCursadaSel == null ? null : _onDivisionChanged,
                ),
                const SizedBox(height: 16),
                // 4) Grupo de taller (grupos de ESTE curso puntual, una vez resuelto)
                _DropdownGroup<WorkshopGroup>(
                  label: 'Grupo de taller',
                  value: _tallerSel,
                  options: _talleres,
                  hint: _divisionSel == null
                      ? 'Elegí año, año de cursada y división'
                      : (_talleresLoading
                          ? 'Cargando...'
                          : (_talleres.isEmpty ? 'Este curso no tiene grupos cargados' : 'Grupo de taller')),
                  itemLabel: (w) => w.name,
                  onChanged: (_divisionSel == null || _talleresLoading || _talleres.isEmpty)
                      ? null
                      : (v) => setState(() => _tallerSel = v),
                ),

                const SizedBox(height: 16),
                // 5) Nombre   ·   6) Apellido   ·   7) DNI
                _FieldGroup(label: 'Nombre', child: _input(_nombreCtrl, 'Ej: María')),
                const SizedBox(height: 16),
                _FieldGroup(label: 'Apellido', child: _input(_apellidoCtrl, 'Ej: Rodríguez')),
                const SizedBox(height: 16),
                _FieldGroup(label: 'DNI', child: _input(_dniCtrl, 'Ej: 12345678', keyboard: TextInputType.number)),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.highlight)),
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
                        : Text('Crear alumno', style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.white))),
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

  Widget _input(TextEditingController controller, String hint, {TextInputType? keyboard}) {
    final theme = AAMTheme();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(10),
      ),
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
}

// ─── Edición de alumno (nombre/DNI + grupos de taller individuales) ───────────
class _EditarAlumnoModal extends StatefulWidget {
  const _EditarAlumnoModal({required this.alumno, required this.onSave});

  final Student alumno;
  final Future<void> Function(Student alumno) onSave;

  @override
  State<_EditarAlumnoModal> createState() => _EditarAlumnoModalState();
}

class _EditarAlumnoModalState extends State<_EditarAlumnoModal> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _dniCtrl;
  bool _submitting = false;
  String? _error;

  final ApiDatasource _ds = ApiDatasource();
  List<WorkshopGroup> _talleres = [];
  WorkshopGroup? _tallerSel;
  bool _talleresLoading = false;
  String? _talleresError;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.alumno.nombre);
    _apellidoCtrl = TextEditingController(text: widget.alumno.apellido);
    _dniCtrl = TextEditingController(text: widget.alumno.dni);
    _cargarTalleres();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _dniCtrl.dispose();
    super.dispose();
  }

  // Los grupos son una subdivisión interna del curso del alumno — no se
  // comparten entre cursos.
  Future<void> _cargarTalleres() async {
    setState(() {
      _talleresLoading = true;
      _talleresError = null;
    });
    try {
      final talleres = await _ds.getWorkshopGroupsByCourse(widget.alumno.cursoId);
      if (!mounted) return;
      WorkshopGroup? actual;
      if (widget.alumno.workshopGroupId != null) {
        try {
          actual = talleres.firstWhere((w) => w.id == widget.alumno.workshopGroupId);
        } catch (_) {
          actual = null;
        }
      }
      setState(() {
        _talleres = talleres;
        _tallerSel = actual;
      });
    } catch (_) {
      if (mounted) setState(() => _talleresError = 'No se pudieron cargar los grupos de taller.');
    } finally {
      if (mounted) setState(() => _talleresLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_nombreCtrl.text.trim().isEmpty ||
        _apellidoCtrl.text.trim().isEmpty ||
        _dniCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Completá nombre, apellido y DNI.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSave(widget.alumno.copyWith(
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        dni: _dniCtrl.text.trim(),
        workshopGroupId: _tallerSel?.id,
        clearWorkshopGroupId: _tallerSel == null,
      ));
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
                    child: const Icon(Icons.edit_outlined, size: 18, color: AAMColors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Editar alumno',
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
                _FieldGroup(label: 'Nombre', child: _input(_nombreCtrl, 'Ej: María')),
                const SizedBox(height: 16),
                _FieldGroup(label: 'Apellido', child: _input(_apellidoCtrl, 'Ej: Rodríguez')),
                const SizedBox(height: 16),
                _FieldGroup(label: 'DNI', child: _input(_dniCtrl, 'Ej: 12345678', keyboard: TextInputType.number)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(10)),
                  child: Text('Curso: ${widget.alumno.curso}',
                    style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
                ),
                const SizedBox(height: 16),
                _buildTalleresSelector(theme),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.highlight)),
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
                        : Text('Guardar cambios', style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.white))),
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

  Widget _buildTalleresSelector(AAMTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grupo de taller',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textSec)),
        const SizedBox(height: 8),
        if (_talleresLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AAMColors.accent)))
        else if (_talleres.isEmpty)
          Text('No hay grupos de taller cargados para este curso.',
            style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec))
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.borderCol),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<WorkshopGroup?>(
              value: _tallerSel,
              underline: const SizedBox.shrink(),
              isExpanded: true,
              style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
              items: [
                DropdownMenuItem<WorkshopGroup?>(
                  value: null,
                  child: Text('Sin asignar', style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
                ),
                ..._talleres.map((w) => DropdownMenuItem<WorkshopGroup?>(value: w, child: Text(w.name))),
              ],
              onChanged: (v) => setState(() => _tallerSel = v),
            ),
          ),
        if (_talleresError != null) ...[
          const SizedBox(height: 6),
          Text(_talleresError!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.highlight)),
        ],
      ],
    );
  }

  Widget _input(TextEditingController controller, String hint, {TextInputType? keyboard}) {
    final theme = AAMTheme();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(10),
      ),
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
        decoration: BoxDecoration(
          border: Border.all(color: theme.borderCol),
          borderRadius: BorderRadius.circular(10),
        ),
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

class _DetalleChip extends StatelessWidget {
  const _DetalleChip({required this.label, required this.value, this.color = AAMColors.border});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = AAMTheme();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        Text(value, style: GoogleFonts.dmSans(fontSize: 12, color: theme.text)),
      ]),
    );
  }
}
