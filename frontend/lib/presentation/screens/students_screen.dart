import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/workshop_group.dart';
import '../../domain/usecases/get_students.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../../infrastructure/repositories/student_repository_impl.dart';
import '../../infrastructure/repositories/course_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class AlumnosScreen extends StatefulWidget {
  const AlumnosScreen({super.key});

  @override
  State<AlumnosScreen> createState() => _AlumnosScreenState();
}

class _AlumnosScreenState extends State<AlumnosScreen> {
  late final StudentRepositoryImpl _repo;
  late final CourseRepositoryImpl _cursoRepo;
  late final GetStudents _getStudents;
  late Future<List<Student>> _future;

  String _searchQuery = '';
  String _filterCurso = 'Todos';
  String _filterEstado = 'Todos';

  @override
  void initState() {
    super.initState();
    final api = ApiDatasource();
    _repo = StudentRepositoryImpl(api);
    _cursoRepo = CourseRepositoryImpl(api);
    _getStudents = GetStudents(_repo);
    _future = _getStudents();
  }

  void _refresh() => setState(() => _future = _getStudents());

  Future<void> _abrirNuevoAlumno() async {
    final cursos = await _cursoRepo.getCourses();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _AlumnoFormModal(
        cursosDisponibles: cursos,
        onSave: (alumno) async {
          await _repo.crearAlumno(alumno.copyWith(id: 'tmp'));
        },
      ),
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
    final cursos = await _cursoRepo.getCourses();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _AlumnoFormModal(
        alumno: alumno,
        cursosDisponibles: cursos,
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
          ('Especialidad', 2),
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
            // Especialidad
            Expanded(flex: 2, child: Text(a.especialidad,
              style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
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
                  Text('${alumno.curso} · ${alumno.especialidad} · ${alumno.turno}',
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
                _DetalleChip(label: 'Turno', value: alumno.turno),
                _DetalleChip(label: 'Especialidad', value: alumno.especialidad),
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

class _AlumnoFormModal extends StatefulWidget {
  const _AlumnoFormModal({this.alumno, required this.cursosDisponibles, required this.onSave});

  final Student? alumno;
  final List<Course> cursosDisponibles;
  final Future<void> Function(Student alumno) onSave;

  @override
  State<_AlumnoFormModal> createState() => _AlumnoFormModalState();
}

class _AlumnoFormModalState extends State<_AlumnoFormModal> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _dniCtrl;
  String? _anioSel;
  String? _divisionSel;
  String? _especialidadSel;
  String? _turnoSel;
  bool _recursante = false;
  bool _loading = false;
  String? _error;

  final ApiDatasource _ds = ApiDatasource();
  List<WorkshopGroup> _catalogoTalleres = [];
  Set<int> _misTalleres = {};
  bool _talleresLoading = false;
  String? _talleresError;

  bool get _esEdicion => widget.alumno != null;

  List<String> get _anios {
    final s = widget.cursosDisponibles.map((c) => c.academicYear).toSet().toList();
    s.sort();
    return s;
  }

  List<String> get _divisiones {
    if (_anioSel == null) return [];
    final s = widget.cursosDisponibles
        .where((c) => c.academicYear == _anioSel)
        .map((c) => c.division)
        .toSet()
        .toList();
    s.sort();
    return s;
  }

  List<String> get _especialidades {
    if (_anioSel == null || _divisionSel == null) return [];
    final s = widget.cursosDisponibles
        .where((c) => c.academicYear == _anioSel && c.division == _divisionSel)
        .map((c) => c.specialty)
        .toSet()
        .toList();
    s.sort();
    return s;
  }

  List<String> get _turnos {
    if (_anioSel == null || _divisionSel == null || _especialidadSel == null) return [];
    final s = widget.cursosDisponibles
        .where((c) => c.academicYear == _anioSel && c.division == _divisionSel && c.specialty == _especialidadSel)
        .map((c) => c.shift)
        .toSet()
        .toList();
    s.sort();
    return s;
  }

  // Un curso se identifica por las 4 dimensiones (año + división + especialidad
  // + turno). Resolver con menos es un bug: pueden existir dos cursos iguales en
  // año/división/especialidad y distinto turno (UNIQUE de `courses` sobre las 4).
  Course? get _cursoResuelto {
    if (_anioSel == null || _divisionSel == null || _especialidadSel == null || _turnoSel == null) {
      return null;
    }
    try {
      return widget.cursosDisponibles.firstWhere((c) =>
          c.academicYear == _anioSel &&
          c.division == _divisionSel &&
          c.specialty == _especialidadSel &&
          c.shift == _turnoSel);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.alumno?.nombre ?? '');
    _apellidoCtrl = TextEditingController(text: widget.alumno?.apellido ?? '');
    _dniCtrl = TextEditingController(text: widget.alumno?.dni ?? '');
    _recursante = widget.alumno?.recursante ?? false;
    if (widget.alumno != null) {
      final actual = widget.cursosDisponibles.where((c) => c.id == widget.alumno!.cursoId).toList();
      if (actual.isNotEmpty) {
        _anioSel = actual.first.academicYear;
        _divisionSel = actual.first.division;
        _especialidadSel = actual.first.specialty;
        _turnoSel = actual.first.shift;
      }
    }
    if (_esEdicion) _cargarTalleres();
  }

  Future<void> _cargarTalleres() async {
    setState(() { _talleresLoading = true; _talleresError = null; });
    try {
      final catalogo = await _ds.getWorkshopGroups();
      final mios = await _ds.getWorkshopGroupsDeAlumno(widget.alumno!.id);
      if (!mounted) return;
      setState(() {
        _catalogoTalleres = catalogo;
        _misTalleres = mios.map((w) => w.id).toSet();
      });
    } catch (e) {
      if (mounted) setState(() => _talleresError = 'No se pudieron cargar los talleres.');
    } finally {
      if (mounted) setState(() => _talleresLoading = false);
    }
  }

  Future<void> _toggleTaller(WorkshopGroup w) async {
    final estaba = _misTalleres.contains(w.id);
    // Optimistic UI; se revierte si el request falla.
    setState(() {
      _talleresError = null;
      estaba ? _misTalleres.remove(w.id) : _misTalleres.add(w.id);
    });
    try {
      if (estaba) {
        await _ds.quitarWorkshopGroupDeAlumno(widget.alumno!.id, w.id);
      } else {
        await _ds.agregarWorkshopGroupAAlumno(widget.alumno!.id, w.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        estaba ? _misTalleres.add(w.id) : _misTalleres.remove(w.id);
        _talleresError = 'No se pudo actualizar el taller.';
      });
    }
  }

  Widget _buildTalleresSelector(AAMTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grupos de taller',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textSec)),
        const SizedBox(height: 8),
        if (!_esEdicion)
          Text('Guardá el alumno para poder asignarle talleres.',
            style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec))
        else if (_talleresLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AAMColors.accent)))
        else if (_catalogoTalleres.isEmpty)
          Text('No hay grupos de taller cargados.',
            style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final w in _catalogoTalleres)
              FilterChip(
                label: Text(w.name),
                selected: _misTalleres.contains(w.id),
                onSelected: (_) => _toggleTaller(w),
                selectedColor: AAMColors.accent.withValues(alpha: 0.2),
                checkmarkColor: AAMColors.primary,
                backgroundColor: theme.surfaceCol,
                labelStyle: GoogleFonts.dmSans(fontSize: 13,
                  color: _misTalleres.contains(w.id) ? AAMColors.primary : theme.text),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.borderCol)),
              ),
          ]),
        if (_talleresError != null) ...[
          const SizedBox(height: 6),
          Text(_talleresError!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.highlight)),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _dniCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final dni = _dniCtrl.text.trim();
    if (_nombreCtrl.text.trim().isEmpty ||
        _apellidoCtrl.text.trim().isEmpty ||
        dni.isEmpty ||
        _anioSel == null ||
        _divisionSel == null ||
        _especialidadSel == null ||
        _turnoSel == null) {
      setState(() => _error = 'Completa todos los campos.');
      return;
    }
    if (!RegExp(r'^\d{8}$').hasMatch(dni)) {
      setState(() => _error = 'El DNI debe tener 8 dígitos.');
      return;
    }
    final curso = _cursoResuelto;
    if (curso == null) {
      setState(() => _error = 'No se encontró el curso seleccionado.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final alumno = Student(
        id: widget.alumno?.id ?? 'tmp',
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        dni: dni,
        cursoId: curso.id,
        curso: curso.name,
        especialidad: curso.specialty,
        turno: curso.shift,
        recursante: _recursante,
        porcentajeAsistencia: widget.alumno?.porcentajeAsistencia ?? 100.0,
      );
      await widget.onSave(alumno);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
                  Expanded(child: Text(
                    widget.alumno == null ? 'Nuevo alumno' : 'Editar alumno',
                    style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: theme.text),
                  )),
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
                _FieldGroup(label: 'Apellido', child: _buildInput(_apellidoCtrl, 'Ej: Rodríguez')),
                const SizedBox(height: 16),
                _FieldGroup(label: 'Nombre', child: _buildInput(_nombreCtrl, 'Ej: María')),
                const SizedBox(height: 16),
                _FieldGroup(label: 'DNI', child: _buildInput(_dniCtrl, 'Ej: 12345678')),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _DropdownGroup<String>(
                    label: 'Año',
                    value: _anioSel,
                    options: _anios,
                    hint: 'Año',
                    itemLabel: (a) => '$a°',
                    onChanged: (v) => setState(() {
                      _anioSel = v;
                      _divisionSel = null;
                      _especialidadSel = null;
                      _turnoSel = null;
                    }),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _DropdownGroup<String>(
                    label: 'División',
                    value: _divisionSel,
                    options: _divisiones,
                    hint: 'División',
                    onChanged: _anioSel == null ? null : (v) => setState(() {
                      _divisionSel = v;
                      _especialidadSel = null;
                      _turnoSel = null;
                    }),
                  )),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _DropdownGroup<String>(
                    label: 'Especialidad',
                    value: _especialidadSel,
                    options: _especialidades,
                    hint: 'Especialidad',
                    onChanged: _divisionSel == null ? null : (v) => setState(() {
                      _especialidadSel = v;
                      _turnoSel = null;
                    }),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _DropdownGroup<String>(
                    label: 'Turno',
                    value: _turnoSel,
                    options: _turnos,
                    hint: 'Turno',
                    onChanged: _especialidadSel == null ? null : (v) => setState(() => _turnoSel = v),
                  )),
                ]),
                if (_cursoResuelto != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.surfaceCol,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Especialidad: ${_cursoResuelto!.specialty}   ·   Turno: ${_cursoResuelto!.shift}',
                      style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  Switch(value: _recursante, onChanged: (v) => setState(() => _recursante = v)),
                  const SizedBox(width: 8),
                  Text('Recursante', style: GoogleFonts.dmSans(fontSize: 14, color: theme.text)),
                ]),
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
                    onTap: _loading ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _loading ? AAMColors.accent.withAlpha((0.6 * 255).round()) : AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                        : Text(widget.alumno == null ? 'Crear alumno' : 'Guardar cambios',
                            style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.white))),
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

  Widget _buildInput(TextEditingController controller, String hint) {
    final theme = AAMTheme();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
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
