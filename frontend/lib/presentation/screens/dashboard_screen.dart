import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/usecases/get_dashboard_summary.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../../infrastructure/repositories/attendance_repository_impl.dart';
import '../../infrastructure/repositories/course_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Inyección de dependencias (manual, sin provider aún) ──────────────────
  late final GetDashboardSummary _getDashboardSummary;
  late Future<DashboardSummary> _future;

  @override
  void initState() {
    super.initState();
    final ds = ApiDatasource();
    _getDashboardSummary = GetDashboardSummary(
      attendanceRepository: AttendanceRepositoryImpl(ds),
      courseRepository:      CourseRepositoryImpl(ds),
    );
    _future = _getDashboardSummary(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AAMTopbar(title: 'Dashboard'),
        Expanded(
          child: FutureBuilder<DashboardSummary>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const AAMLoadingScreen();
              }
              if (snap.hasError) {
                return AAMErrorWidget(
                  message: 'Error al cargar el dashboard',
                  onRetry: () => setState(() { _future = _getDashboardSummary(DateTime.now()); }),
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
  final DashboardSummary data;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return _buildContent(theme);
      },
    );
  }

  Widget _buildContent(AAMTheme theme) {
    final g = data.globalSummary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(theme),
          const SizedBox(height: 28),

          // Stats row
          Row(children: [
            Expanded(child: AAMStatCard(
              label: 'Alumnos presentes', value: '${g.present}',
              color: AAMColors.success, icon: Icons.how_to_reg_outlined,
            )),
            const SizedBox(width: 16),
            Expanded(child: AAMStatCard(
              label: 'Ausentes hoy',   value: '${g.absent}',
              color: AAMColors.danger, icon: Icons.person_off_outlined,
            )),
            const SizedBox(width: 16),
            Expanded(child: AAMStatCard(
              label: 'Cursos activos', value: '${data.courses.length}',
              color: AAMColors.accent, icon: Icons.class_outlined,
            )),
            const SizedBox(width: 16),
            Expanded(child: AAMStatCard(
              label: 'Retiros anticipados', value: '${g.earlyDepartures}',
              color: AAMColors.warning, icon: Icons.exit_to_app_outlined,
            )),
          ]),
          const SizedBox(height: 28),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: Column(children: [
                _buildAttendanceCard(theme),
                const SizedBox(height: 24),
                _buildCoursesCard(theme),
              ])),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: Column(children: [
                _buildAlertsCard(theme),
                const SizedBox(height: 24),
                _buildDevicesCard(theme),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(AAMTheme theme) {
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
              style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: theme.text)),
            Text('$fechaStr · Turno Mañana',
              style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
          ],
        )),
        const AAMBadge(label: '● Sistema activo', color: AAMColors.success),
      ],
    );
  }

  Widget _buildAttendanceCard(AAMTheme theme) {
    final g  = data.globalSummary;
    final pct = g.attendancePercentage;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Asistencia global hoy',
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
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
              backgroundColor: theme.surfaceCol,
              valueColor: const AlwaysStoppedAnimation<Color>(AAMColors.accent),
            ),
          ),
          const SizedBox(height: 20),
          _shiftRow('Turno Mañana',    data.morningSummary, theme),
          const SizedBox(height: 10),
          _shiftRow('Turno Tarde',     data.afternoonSummary, theme),
          const SizedBox(height: 10),
          _shiftRow('Turno Vespertino',data.eveningSummary, theme),
        ],
      ),
    );
  }

  Widget _shiftRow(String label, AttendanceSummary r, AAMTheme theme) {
    final pct = r.attendancePercentage / 100;
    return Row(
      children: [
        SizedBox(width: 130,
          child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct, minHeight: 7,
            backgroundColor: theme.surfaceCol,
            valueColor: const AlwaysStoppedAnimation<Color>(AAMColors.primary),
          ),
        )),
        const SizedBox(width: 12),
        Text('${r.present}/${r.total}',
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.text)),
      ],
    );
  }

  Widget _buildCoursesCard(AAMTheme theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Cursos activos',
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
            const Spacer(),
            const AAMButton(label: 'Ver todos', outlined: true),
          ]),
          const SizedBox(height: 16),
          ...data.courses.take(5).map((c) => _CourseRow(course: c, theme: theme)),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(AAMTheme theme) {
    // No hay un concepto de "alerta" en el schema ni un endpoint que las
    // calcule todavía (requeriría agregaciones sobre attendance_records:
    // ausencias consecutivas, retiros pendientes, etc.) — placeholder
    // honesto en vez de datos inventados.
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alertas recientes',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
          const SizedBox(height: 16),
          _CardEmptyState(
            icon: Icons.notifications_none_outlined,
            message: 'Todavía no hay un cálculo de alertas disponible.',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesCard(AAMTheme theme) {
    // `devices` existe en la DB pero no hay endpoint que exponga su estado
    // (online/offline) todavía — placeholder honesto en vez de datos inventados.
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.nfc, size: 18, color: theme.text),
            const SizedBox(width: 8),
            Text('Dispositivos ESP32',
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
          ]),
          const SizedBox(height: 16),
          _CardEmptyState(
            icon: Icons.nfc_outlined,
            message: 'Todavía no hay un endpoint que exponga el estado de los lectores.',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _CardEmptyState extends StatelessWidget {
  const _CardEmptyState({required this.icon, required this.message, required this.theme});
  final IconData icon;
  final String message;
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: theme.textSec),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
          style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec))),
      ]),
    );
  }
}

// ─── Fila de curso ─────────────────────────────────────────────────────────────
class _CourseRow extends StatefulWidget {
  const _CourseRow({required this.course, required this.theme});
  final Course course;
  final AAMTheme theme;

  @override
  State<_CourseRow> createState() => _CourseRowState();
}

class _CourseRowState extends State<_CourseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final theme = widget.theme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? theme.surfaceCol : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: theme.surfaceCol, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.school_outlined, size: 16, color: theme.text),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(c.name,
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text))),
          Text(c.schedule,
            style: GoogleFonts.dmSans(fontSize: 12, color: theme.textSec)),
          const SizedBox(width: 12),
          Text('${c.totalStudents} alumnos',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: AAMColors.textSec),
        ]),
      ),
    );
  }
}