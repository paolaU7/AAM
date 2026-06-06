import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/curso.dart';
import '../../domain/usecases/get_resumen_dashboard.dart';
import '../../infrastructure/datasources/mock_datasource.dart';
import '../../infrastructure/repositories/asistencia_repository_impl.dart';
import '../../infrastructure/repositories/curso_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Inyección de dependencias (manual, sin provider aún) ──────────────────
  late final GetResumenDashboard _getResumen;
  late Future<ResumenDashboard> _future;

  @override
  void initState() {
    super.initState();
    final ds = MockDatasource();
    _getResumen = GetResumenDashboard(
      asistenciaRepository: AsistenciaRepositoryImpl(ds),
      cursoRepository:      CursoRepositoryImpl(ds),
    );
    _future = _getResumen(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AAMTopbar(title: 'Dashboard'),
        Expanded(
          child: FutureBuilder<ResumenDashboard>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const AAMLoadingScreen();
              }
              if (snap.hasError) {
                return AAMErrorWidget(
                  message: 'Error al cargar el dashboard',
                  onRetry: () => setState(() => _future = _getResumen(DateTime.now())),
                );
              }
              return _DashboardContent(data: snap.data!);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Contenido del dashboard (recibe datos ya resueltos) ──────────────────────
class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});
  final ResumenDashboard data;

  @override
  Widget build(BuildContext context) {
    final g = data.resumenGlobal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(),
          const SizedBox(height: 28),

          // Stats row
          Row(children: [
            Expanded(child: AAMStatCard(
              label: 'Alumnos presentes', value: '${g.presentes}',
              color: AAMColors.accent,   icon: Icons.how_to_reg_outlined,
            )),
            const SizedBox(width: 16),
            Expanded(child: AAMStatCard(
              label: 'Ausentes hoy',   value: '${g.ausentes}',
              color: AAMColors.highlight, icon: Icons.person_off_outlined,
            )),
            const SizedBox(width: 16),
            Expanded(child: AAMStatCard(
              label: 'Cursos activos', value: '${data.cursos.length}',
              color: AAMColors.primary, icon: Icons.class_outlined,
            )),
            const SizedBox(width: 16),
            Expanded(child: AAMStatCard(
              label: 'Retiros anticipados', value: '${g.retiros}',
              color: AAMColors.warning, icon: Icons.exit_to_app_outlined,
            )),
          ]),
          const SizedBox(height: 28),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: Column(children: [
                _buildAsistenciaCard(),
                const SizedBox(height: 24),
                _buildCursosCard(),
              ])),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: Column(children: [
                _buildAlertasCard(),
                const SizedBox(height: 24),
                _buildDispositivosCard(),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final now = DateTime.now();
    final dias = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    final meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final fechaStr = '${dias[now.weekday - 1]} ${now.day} de ${meses[now.month - 1]} ${now.year}';

    return Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buenos días, Dirección',
              style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: AAMColors.primary)),
            Text('$fechaStr · Turno Mañana',
              style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.textSec)),
          ],
        )),
        const AAMBadge(label: '● Sistema activo', color: AAMColors.success),
      ],
    );
  }

  Widget _buildAsistenciaCard() {
    final g  = data.resumenGlobal;
    final pct = g.porcentajeAsistencia;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Asistencia global hoy',
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AAMColors.primary)),
            const Spacer(),
            Text('${pct.toStringAsFixed(0)}%',
              style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: AAMColors.accent)),
          ]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 10,
              backgroundColor: AAMColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AAMColors.accent),
            ),
          ),
          const SizedBox(height: 20),
          _turnoRow('Turno Mañana',    data.resumenManiana),
          const SizedBox(height: 10),
          _turnoRow('Turno Tarde',     data.resumenTarde),
          const SizedBox(height: 10),
          _turnoRow('Turno Vespertino',data.resumenVespertino),
        ],
      ),
    );
  }

  Widget _turnoRow(String label, ResumenAsistencia r) {
    final pct = r.porcentajeAsistencia / 100;
    return Row(
      children: [
        SizedBox(width: 130,
          child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct, minHeight: 7,
            backgroundColor: AAMColors.surface,
            valueColor: const AlwaysStoppedAnimation<Color>(AAMColors.primary),
          ),
        )),
        const SizedBox(width: 12),
        Text('${r.presentes}/${r.total}',
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AAMColors.primary)),
      ],
    );
  }

  Widget _buildCursosCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Cursos activos',
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AAMColors.primary)),
            const Spacer(),
            const AAMButton(label: 'Ver todos', outlined: true),
          ]),
          const SizedBox(height: 16),
          ...data.cursos.take(5).map((c) => _CursoRow(curso: c)),
        ],
      ),
    );
  }

  Widget _buildAlertasCard() {
    // Alertas estáticas — en producción vendrían de un AlertasRepository
    final alertas = [
      (Icons.warning_amber_outlined, AAMColors.highlight,  'González, Lucas A.',  '3° ausencia consecutiva · 5° 3°', '08:42'),
      (Icons.exit_to_app_outlined,   AAMColors.warning,    'Ferreyra, Ana P.',    'Retiro anticipado pendiente · 4° 2°', '09:15'),
      (Icons.info_outline,           AAMColors.accent,     'Romero, Diego E.',    'Falta no computable · recursante', 'ayer'),
      (Icons.person_off_outlined,    AAMColors.highlight,  'Torres, Valentina',   'Ausente sin justificar · 3° 2°', '07:58'),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alertas recientes',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AAMColors.primary)),
          const SizedBox(height: 16),
          ...alertas.map((a) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: a.$2.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(a.$1, size: 18, color: a.$2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.$3, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AAMColors.primary)),
                  Text(a.$4, style: GoogleFonts.dmSans(fontSize: 11, color: AAMColors.textSec)),
                ],
              )),
              Text(a.$5, style: GoogleFonts.dmSans(fontSize: 11, color: AAMColors.textSec)),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildDispositivosCard() {
    final dispositivos = [
      ('Lector — Entrada Principal', true),
      ('Lector — Puerta Lateral',    true),
      ('Lector — Taller 3',          false),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.nfc, size: 18, color: AAMColors.primary),
            const SizedBox(width: 8),
            Text('Dispositivos ESP32',
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AAMColors.primary)),
          ]),
          const SizedBox(height: 16),
          ...dispositivos.map((d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: d.$2 ? AAMColors.success : AAMColors.highlight,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(d.$1,
                style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.primary))),
              AAMBadge(
                label: d.$2 ? 'Online' : 'Offline',
                color: d.$2 ? AAMColors.success : AAMColors.highlight,
              ),
            ]),
          )),
        ],
      ),
    );
  }
}

// ─── Fila de curso ─────────────────────────────────────────────────────────────
class _CursoRow extends StatefulWidget {
  const _CursoRow({required this.curso});
  final Curso curso;

  @override
  State<_CursoRow> createState() => _CursoRowState();
}

class _CursoRowState extends State<_CursoRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.curso;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? AAMColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: AAMColors.surface, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.school_outlined, size: 16, color: AAMColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(c.nombre,
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AAMColors.primary))),
          Text(c.horario,
            style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.textSec)),
          const SizedBox(width: 12),
          Text('${c.totalAlumnos} alumnos',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AAMColors.primary)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: AAMColors.textSec),
        ]),
      ),
    );
  }
}
