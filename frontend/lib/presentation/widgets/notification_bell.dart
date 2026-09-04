import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/notification.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import 'aam_design_system.dart';
import 'auto_refresh_mixin.dart';

/// Ícono de campana del header, con desplegable de alertas calculadas al
/// vuelo (reemplazos de preceptor por vencer, excepciones de horario
/// próximas, alumnos con faltas consecutivas). Sin tabla ni estado de
/// leído/no leído — el puntito rojo aparece si hay ≥1 alerta activa y
/// desaparece si no hay ninguna.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with AutoRefreshMixin<NotificationBell> {
  final ApiDatasource _ds = ApiDatasource();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
    startAutoRefresh();
  }

  @override
  void onAutoRefresh() => _cargar();

  @override
  void dispose() {
    _cerrarPanel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final data = await _ds.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = data;
          _loading = false;
        });
        _overlayEntry?.markNeedsBuild();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _togglePanel() {
    if (_overlayEntry != null) {
      _cerrarPanel();
      return;
    }
    _cargar(); // refresca cada vez que se abre — no hay estado que persistir
    _overlayEntry = _crearOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _cerrarPanel() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _crearOverlay() {
    return OverlayEntry(
      builder: (context) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _cerrarPanel,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 10),
          child: _NotificationPanel(notifications: _notifications, loading: _loading),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _togglePanel,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Stack(children: [
            Icon(Icons.notifications_outlined, size: 22, color: AAMTheme().textSec),
            if (_notifications.isNotEmpty)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AAMColors.highlight, shape: BoxShape.circle),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({required this.notifications, required this.loading});
  final List<AppNotification> notifications;
  final bool loading;

  (IconData, Color) _estiloPara(String type) => switch (type) {
        'preceptor_temp_assignment' => (Icons.person_off_outlined, AAMColors.warning),
        'schedule_exception' => (Icons.event_note_outlined, AAMColors.violet),
        'consecutive_absences' => (Icons.trending_down_outlined, AAMColors.highlight),
        _ => (Icons.notifications_none_outlined, AAMColors.slate),
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: AAMTheme(),
        builder: (context, _) {
          final theme = AAMTheme();
          return Container(
            width: 360,
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.borderCol),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.14 * 255).round()), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(children: [
                  Text('Notificaciones', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text)),
                  const Spacer(),
                  if (notifications.isNotEmpty)
                    AAMBadge(label: '${notifications.length}', color: AAMColors.highlight),
                ]),
              ),
              Divider(height: 1, color: theme.borderCol),
              Flexible(
                child: loading
                    ? const Padding(padding: EdgeInsets.all(24), child: AAMLoadingScreen())
                    : notifications.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.notifications_none_outlined, size: 32, color: theme.borderCol),
                              const SizedBox(height: 10),
                              Text('Sin alertas por ahora', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
                            ]),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: notifications.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: theme.borderCol),
                            itemBuilder: (context, i) {
                              final n = notifications[i];
                              final (icon, color) = _estiloPara(n.type);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(color: color.withAlpha((0.12 * 255).round()), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(icon, size: 15, color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(n.message, style: GoogleFonts.dmSans(fontSize: 13, color: theme.text, height: 1.35))),
                                ]),
                              );
                            },
                          ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
