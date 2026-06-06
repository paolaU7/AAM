import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Tokens de color ──────────────────────────────────────────────────────────
class AAMColors {
  static const Color primary   = Color(0xFF084B83);
  static const Color accent    = Color(0xFF42BFDD);
  static const Color mint      = Color(0xFFBBE6E4);
  static const Color surface   = Color(0xFFF0F6F6);
  static const Color highlight = Color(0xFFFF66B3);
  static const Color white     = Color(0xFFFFFFFF);
  static const Color textSec   = Color(0xFF6B7280);
  static const Color border    = Color(0x14084B83);
  static const Color success   = Color(0xFF16A34A);
  static const Color warning   = Color(0xFFD97706);
}

// ─── Topbar ───────────────────────────────────────────────────────────────────
class AAMTopbar extends StatelessWidget {
  const AAMTopbar({super.key, required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: AAMColors.white,
        border: Border(bottom: BorderSide(color: AAMColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 18, fontWeight: FontWeight.w700, color: AAMColors.primary,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
          const SizedBox(width: 12),
          Stack(children: [
            const Icon(Icons.notifications_outlined, size: 22, color: AAMColors.textSec),
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AAMColors.highlight, shape: BoxShape.circle),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          const Icon(Icons.settings_outlined, size: 22, color: AAMColors.textSec),
        ],
      ),
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
          Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec)),
        ],
      ),
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
                ? Border.all(color: AAMColors.primary, width: 2)
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: AAMColors.white),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: widget.outlined
                      ? (_hovered ? AAMColors.white : AAMColors.primary)
                      : AAMColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AAMColors.highlight, size: 40),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.textSec)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            AAMButton(label: 'Reintentar', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

// ─── Tabla header helper ──────────────────────────────────────────────────────
class AAMTableHeader extends StatelessWidget {
  const AAMTableHeader({super.key, required this.columns});
  final List<(String label, int flex)> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AAMColors.border, width: 1)),
      ),
      child: Row(
        children: columns.map((c) => Expanded(
          flex: c.$2,
          child: Text(
            c.$1,
            style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AAMColors.textSec, letterSpacing: 0.5,
            ),
          ),
        )).toList(),
      ),
    );
  }
}
