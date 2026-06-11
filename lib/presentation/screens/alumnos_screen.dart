import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/alumno.dart';
import '../../domain/usecases/get_alumnos.dart';
import '../../infraestructure/datasources/mock_datasource.dart';
import '../../infraestructure/repositories/alumno_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class AlumnosScreen extends StatefulWidget {
  const AlumnosScreen({super.key});

  @override
  State<AlumnosScreen> createState() => _AlumnosScreenState();
}

class _AlumnosScreenState extends State<AlumnosScreen> {
  late final GetAlumnos _getAlumnos;
  late Future<List<Alumno>> _future;

  String _searchQuery = '';
  String _filterCurso = 'Todos';

  @override
  void initState() {
    super.initState();
    _getAlumnos = GetAlumnos(AlumnoRepositoryImpl(MockDatasource()));
    _future = _getAlumnos();
  }

  List<Alumno> _applyFilters(List<Alumno> all) {
    return all.where((a) {
      final matchSearch = _searchQuery.isEmpty ||
          a.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.dni.contains(_searchQuery) ||
          a.curso.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCurso = _filterCurso == 'Todos' || a.curso == _filterCurso;
      return matchSearch && matchCurso;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AAMTopbar(
          title: 'Alumnos',
          actions: [
            const AAMButton(label: 'Nuevo alumno',   icon: Icons.add),
            const SizedBox(width: 8),
            const AAMButton(label: 'Importar Excel', icon: Icons.upload_file_outlined, outlined: true),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Alumno>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const AAMLoadingScreen();
              if (snap.hasError) return AAMErrorWidget(
                message: 'Error al cargar alumnos',
                onRetry: () => setState(() => _future = _getAlumnos()),
              );

              final alumnos  = _applyFilters(snap.data!);
              final cursoOpts = ['Todos', ...snap.data!.map((a) => a.curso).toSet().toList()..sort()];

              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  _buildFilters(cursoOpts, snap.data!.length, alumnos.length),
                  const SizedBox(height: 24),
                  Expanded(child: _buildTable(alumnos)),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(List<String> cursos, int total, int filtered) {
    return Row(children: [
      Expanded(
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: AAMColors.white,
            border: Border.all(color: AAMColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.primary),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, DNI o curso...',
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.textSec),
              prefixIcon: const Icon(Icons.search, size: 18, color: AAMColors.textSec),
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
          color: AAMColors.white,
          border: Border.all(color: AAMColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButton<String>(
          value: _filterCurso,
          underline: const SizedBox.shrink(),
          style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.primary),
          items: cursos.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _filterCurso = v ?? 'Todos'),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        '$filtered de $total alumnos',
        style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec),
      ),
    ]);
  }

  Widget _buildTable(List<Alumno> alumnos) {
    return Container(
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
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
          child: ListView.builder(
            itemCount: alumnos.length,
            itemBuilder: (ctx, i) => _AlumnoRow(alumno: alumnos[i]),
          ),
        ),
      ]),
    );
  }
}

// ─── Fila de alumno ───────────────────────────────────────────────────────────
class _AlumnoRow extends StatefulWidget {
  const _AlumnoRow({required this.alumno});
  final Alumno alumno;

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _hovered ? AAMColors.surface : AAMColors.white,
          border: const Border(bottom: BorderSide(color: AAMColors.border, width: 1)),
        ),
        child: Row(children: [
          // Alumno
          Expanded(flex: 3, child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AAMColors.mint,
              child: Text(a.apellido.substring(0, 1),
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AAMColors.primary)),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.nombreCompleto,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AAMColors.primary)),
              if (a.recursante)
                Text('Recursante',
                  style: GoogleFonts.dmSans(fontSize: 10, color: AAMColors.textSec)),
            ]),
          ])),
          // Curso
          Expanded(flex: 2, child: Text(a.curso,
            style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.primary))),
          // Especialidad
          Expanded(flex: 2, child: Text(a.especialidad,
            style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec))),
          // DNI
          Expanded(flex: 2, child: Text(a.dni,
            style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec))),
          // Asistencia
          Expanded(flex: 2, child: Text(
            '${a.porcentajeAsistencia.toStringAsFixed(1)}%',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _asistColor),
          )),
          // Estado
          Expanded(flex: 2, child: AAMBadge(label: estadoLabel, color: estadoColor)),
          // Acciones
          Expanded(flex: 1, child: Row(children: [
            Icon(Icons.visibility_outlined, size: 16,
              color: _hovered ? AAMColors.primary : AAMColors.textSec),
            const SizedBox(width: 10),
            Icon(Icons.edit_outlined, size: 16,
              color: _hovered ? AAMColors.primary : AAMColors.textSec),
          ])),
        ]),
      ),
    );
  }
}
