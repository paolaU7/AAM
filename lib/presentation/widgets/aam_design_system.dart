import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Tokens de color ──────────────────────────────────────────────────────────
class AAMColors {
  // ── Paleta base ──
  static const Color primary    = Color(0xFF1B3A5C);   // azul marino profundo
  static const Color accent     = Color(0xFF2E86AB);   // cyan petróleo
  static const Color surface    = Color(0xFFF4F7FA);   // gris frío muy suave
  static const Color white      = Color(0xFFFFFFFF);
  static const Color textSec    = Color(0xFF6B7A90);   // slate medio
  static const Color border     = Color(0xFFE2E8F0);   // slate claro

  // ── Semánticos (solo donde tienen sentido real) ──
  static const Color success    = Color(0xFF2D9E6B);   // verde teal apagado
  static const Color danger     = Color(0xFFD95F5F);   // rojo suave
  static const Color warning    = Color(0xFFD48B3A);   // ámbar apagado
  static const Color info       = Color(0xFF6B8CBA);   // índigo suave

  // ── Nuevos acentos para reemplazar rosa/highlight ──
  static const Color violet     = Color(0xFF7C6FAF);   // violeta elegante
  static const Color teal       = Color(0xFF3D8F8F);   // teal apagado
  static const Color indigo     = Color(0xFF4A6FA5);   // índigo medio
  static const Color slate      = Color(0xFF8895A7);   // slate neutro

  // ── Dark mode ──
  static const Color darkBg         = Color(0xFF0F1923);
  static const Color darkSurface    = Color(0xFF1A2535);
  static const Color darkCard       = Color(0xFF1E2D3D);
  static const Color darkBorder     = Color(0xFF2A3A4D);
  static const Color darkText       = Color(0xFFE2E8F0);
  static const Color darkTextSec    = Color(0xFF8895A7);

  // ── Semánticos heredados (mantener compatibilidad) ──
  // highlight → violet (reemplazar usos no semánticos)
  // mint → surface con opacidad
  static const Color highlight  = violet;   // alias para no romper código existente
  static const Color mint       = Color(0xFFD6EAF0);   // cyan muy suave
}

// ─── Theme Controller ─────────────────────────────────────────────────────────
class AAMTheme extends ChangeNotifier {
  static final AAMTheme _instance = AAMTheme._();
  factory AAMTheme() => _instance;
  AAMTheme._();

  bool _isDark = false;
  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  // Tokens resueltos según el modo activo
  Color get bg         => _isDark ? AAMColors.darkBg      : AAMColors.surface;
  Color get card       => _isDark ? AAMColors.darkCard     : AAMColors.white;
  Color get sidebar    => _isDark ? AAMColors.darkSurface  : AAMColors.white;
  Color get borderCol  => _isDark ? AAMColors.darkBorder   : AAMColors.border;
  Color get text       => _isDark ? AAMColors.darkText     : AAMColors.primary;
  Color get textSec    => _isDark ? AAMColors.darkTextSec  : AAMColors.textSec;
  Color get inputBg    => _isDark ? AAMColors.darkCard     : AAMColors.white;
  Color get surfaceCol => _isDark ? AAMColors.darkSurface  : AAMColors.surface;
}

// ─── Topbar ───────────────────────────────────────────────────────────────────
class AAMTopbar extends StatelessWidget {
  const AAMTopbar({super.key, required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: theme.card,
            border: Border(bottom: BorderSide(color: theme.borderCol, width: 1)),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 18, fontWeight: FontWeight.w700, color: theme.text,
                ),
              ),
              const Spacer(),
              if (actions != null) ...actions!,
              const SizedBox(width: 12),
              Stack(children: [
                Icon(Icons.notifications_outlined, size: 22, color: theme.textSec),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: AAMColors.highlight, shape: BoxShape.circle),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              const AAMThemeToggle(),
            ],
          ),
        );
      },
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class AAMStatCard extends StatelessWidget {
  const AAMStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
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
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────
class AAMBadge extends StatelessWidget {
  const AAMBadge({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11, fontWeight: FontWeight.w600, color: color,
        ),
      ),
    );
  }
}

// ─── Botón primario ───────────────────────────────────────────────────────────
class AAMButton extends StatefulWidget {
  const AAMButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.outlined = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  State<AAMButton> createState() => _AAMButtonState();
}

class _AAMButtonState extends State<AAMButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit:  (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: widget.outlined
                    ? (_hovered ? AAMColors.primary : Colors.transparent)
                    : (_hovered ? const Color(0xFF35B5D4) : AAMColors.accent),
                border: widget.outlined
                    ? Border.all(color: theme.text, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: widget.outlined
                      ? (_hovered ? AAMColors.white : theme.text)
                      : AAMColors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: widget.outlined
                          ? (_hovered ? AAMColors.white : theme.text)
                          : AAMColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Loading state ────────────────────────────────────────────────────────────
class AAMLoadingScreen extends StatelessWidget {
  const AAMLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AAMColors.accent, strokeWidth: 2),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────
class AAMErrorWidget extends StatelessWidget {
  const AAMErrorWidget({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AAMColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(message, style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                AAMButton(label: 'Reintentar', onPressed: onRetry),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Tabla header helper ──────────────────────────────────────────────────────
class AAMTableHeader extends StatelessWidget {
  const AAMTableHeader({super.key, required this.columns});
  final List<(String label, int flex)> columns;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.borderCol, width: 1)),
          ),
          child: Row(
            children: columns.map((c) => Expanded(
              flex: c.$2,
              child: Text(
                c.$1,
                style: GoogleFonts.dmSans(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: theme.textSec, letterSpacing: 0.5,
                ),
              ),
            )).toList(),
          ),
        );
      },
    );
  }
}

// ─── Theme Toggle ─────────────────────────────────────────────────────────────
class AAMThemeToggle extends StatefulWidget {
  const AAMThemeToggle({super.key});

  @override
  State<AAMThemeToggle> createState() => _AAMThemeToggleState();
}

class _AAMThemeToggleState extends State<AAMThemeToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  final _theme = AAMTheme();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _theme.addListener(_onThemeChange);
    if (_theme.isDark) _ctrl.value = 1.0;
  }

  void _onThemeChange() {
    if (_theme.isDark) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _theme.removeListener(_onThemeChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _theme.toggle(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52, height: 28,
        decoration: BoxDecoration(
          color: _theme.isDark ? AAMColors.accent : AAMColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: _theme.isDark ? 26 : 2,
            top: 2,
            child: Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: AAMColors.white, shape: BoxShape.circle),
              child: Icon(
                _theme.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 14,
                color: _theme.isDark ? AAMColors.accent : AAMColors.textSec,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
