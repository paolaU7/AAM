import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/aam_design_system.dart';
import '../screens/dashboard_screen.dart';
import '../screens/alumnos_screen.dart';
import '../screens/asistencia_screen.dart';
import '../screens/horarios_screen.dart';
import '../screens/usuarios_screen.dart';
import '../screens/reportes_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined,       label: 'Dashboard',     index: 0),
    _NavItem(icon: Icons.people_outline,           label: 'Alumnos',       index: 1),
    _NavItem(icon: Icons.fact_check_outlined,      label: 'Asistencia',    index: 2),
    _NavItem(icon: Icons.schedule_outlined,        label: 'Horarios',      index: 3),
    _NavItem(icon: Icons.manage_accounts_outlined, label: 'Usuarios',      index: 4),
    _NavItem(icon: Icons.bar_chart_outlined,       label: 'Reportes',      index: 5),
    _NavItem(icon: Icons.settings_outlined,        label: 'Configuración', index: 6),
  ];

  Widget get _currentScreen => switch (_selectedIndex) {
    0 => const DashboardScreen(),
    1 => const AlumnosScreen(),
    2 => const AsistenciaScreen(),
    3 => const HorariosScreen(),
    4 => const UsuariosScreen(),
    5 => const ReportesScreen(),
    6 => const _ConfiguracionPlaceholder(),
    _ => const DashboardScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Scaffold(
          backgroundColor: theme.bg,
          body: Row(
            children: [
              _Sidebar(
                navItems:      _navItems,
                selectedIndex: _selectedIndex,
                onItemTap:     (i) => setState(() => _selectedIndex = i),
                theme:         theme,
              ),
              Expanded(child: _currentScreen),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.navItems,
    required this.selectedIndex,
    required this.onItemTap,
    required this.theme,
  });
  final List<_NavItem> navItems;
  final int selectedIndex;
  final void Function(int) onItemTap;
  final AAMTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: theme.sidebar,
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.borderCol, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AAMColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.nfc, color: AAMColors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'AAM',
                  style: GoogleFonts.dmSans(
                    fontSize: 20, fontWeight: FontWeight.w700, color: AAMColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Column(
                children: navItems.map((item) => _SidebarTile(
                  item:     item,
                  selected: item.index == selectedIndex,
                  onTap:    () => onItemTap(item.index),
                  theme:    theme,
                )).toList(),
              ),
            ),
          ),

          // Footer usuario
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.borderCol, width: 1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AAMColors.mint,
                  child: Text(
                    'DI',
                    style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w700, color: AAMColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dirección',
                        style: GoogleFonts.dmSans(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AAMColors.primary,
                        ),
                      ),
                      Text(
                        'adm.dir',
                        style: GoogleFonts.dmSans(fontSize: 10, color: AAMColors.textSec),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.logout_outlined, size: 16, color: AAMColors.textSec),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({required this.item, required this.selected, required this.onTap, required this.theme});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final AAMTheme theme;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AAMColors.primary
                : (_hovered ? widget.theme.surfaceCol : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 18,
                color: widget.selected ? AAMColors.white
                    : (_hovered ? AAMColors.primary : widget.theme.textSec),
              ),
              const SizedBox(width: 10),
              Text(
                widget.item.label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.selected ? AAMColors.white
                      : (_hovered ? AAMColors.primary : widget.theme.textSec),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.index});
  final IconData icon;
  final String label;
  final int index;
}

class _ConfiguracionPlaceholder extends StatelessWidget {
  const _ConfiguracionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const AAMTopbar(title: 'Configuración'),
      Expanded(child: Center(child: Text('Próximamente',
        style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.textSec),
      ))),
    ]);
  }
}
