import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/usecases/crear_usuario.dart';
import '../../infraestructure/datasources/mock_datasource.dart';
import '../../infraestructure/repositories/usuario_repository_impl.dart';
import '../widgets/aam_design_system.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  late final UsuarioRepositoryImpl _repo;
  late final CrearUsuario _crearUsuario;
  late Future<List<Usuario>> _future;

  @override
  void initState() {
    super.initState();
    _repo         = UsuarioRepositoryImpl(MockDatasource());
    _crearUsuario = CrearUsuario(_repo);
    _future       = _repo.getUsuarios();
  }

  void _refresh() => setState(() => _future = _repo.getUsuarios());

  void _abrirModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevoUsuarioModal(
        onCreate: (nombre, apellido, rol, turno) async {
          await _crearUsuario(
            nombre:   nombre,
            apellido: apellido,
            rol:      rol,
            turno:    turno,
          );
          _refresh();
        },
      ),
    );
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
          title: 'Usuarios',
          actions: [
            AAMButton(
              label: 'Nuevo usuario',
              icon: Icons.person_add_outlined,
              onPressed: _abrirModal,
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Usuario>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const AAMLoadingScreen();
              }
              if (snap.hasError) {
                return AAMErrorWidget(
                  message: 'Error al cargar usuarios', onRetry: _refresh,
                );
              }

              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  _buildBanner(theme),
                  const SizedBox(height: 20),
                  Expanded(child: _buildTabla(snap.data!, theme)),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(AAMTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AAMColors.mint.withAlpha((0.3 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AAMColors.accent.withAlpha((0.3 * 255).round())),
      ),
      child: Row(children: [
        const Icon(Icons.shield_outlined, size: 18, color: AAMColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Solo dirección puede crear y gestionar cuentas. '
          'Los usuarios se generan automáticamente en formato apellido.nombre.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.primary),
        )),
      ]),
    );
  }

  Widget _buildTabla(List<Usuario> usuarios, AAMTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(color: theme.borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const AAMTableHeader(columns: [
          ('Nombre',  2),
          ('Usuario', 2),
          ('Rol',     2),
          ('Turno',   2),
          ('Estado',  2),
          ('',        1),
        ]),
        Expanded(
          child: usuarios.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 40, color: theme.borderCol),
                    const SizedBox(height: 12),
                    Text('No hay usuarios cargados',
                      style: GoogleFonts.dmSans(fontSize: 14, color: theme.textSec)),
                    const SizedBox(height: 8),
                    AAMButton(label: 'Crear primer usuario', onPressed: _abrirModal),
                  ],
                ))
              : ListView.builder(
                  itemCount: usuarios.length,
                  itemBuilder: (ctx, i) => _UsuarioRow(
                    usuario: usuarios[i],
                    theme: theme,
                    onToggle: () async {
                      await _repo.toggleActivo(usuarios[i].id);
                      _refresh();
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}

// ─── Fila de usuario ──────────────────────────────────────────────────────────
class _UsuarioRow extends StatefulWidget {
  const _UsuarioRow({required this.usuario, required this.theme, required this.onToggle});
  final Usuario usuario;
  final AAMTheme theme;
  final VoidCallback onToggle;

  @override
  State<_UsuarioRow> createState() => _UsuarioRowState();
}

class _UsuarioRowState extends State<_UsuarioRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    final isDireccion = u.rol == RolUsuario.direccion;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _hovered ? widget.theme.surfaceCol : widget.theme.card,
          border: Border(bottom: BorderSide(color: widget.theme.borderCol, width: 1)),
        ),
        child: Row(children: [
          Expanded(flex: 2, child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isDireccion ? AAMColors.primary : AAMColors.mint,
              child: Text(u.apellido.substring(0, 1),
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                  color: isDireccion ? AAMColors.white : AAMColors.primary)),
            ),
            const SizedBox(width: 10),
            Text(u.nombreCompleto,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: widget.theme.text)),
          ])),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: widget.theme.surfaceCol,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(u.username,
              style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: widget.theme.text)),
          )),
          Expanded(flex: 2, child: AAMBadge(
            label: u.rol.label,
            color: isDireccion ? AAMColors.primary : AAMColors.accent,
          )),
          Expanded(flex: 2, child: Text(u.turno ?? '—',
            style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
          Expanded(flex: 2, child: AAMBadge(
            label: u.activo ? 'Activo' : 'Inactivo',
            color: u.activo ? AAMColors.success : AAMColors.textSec,
          )),
          Expanded(flex: 1, child: GestureDetector(
            onTap: widget.onToggle,
            child: Icon(Icons.block_outlined, size: 15,
              color: _hovered ? AAMColors.highlight : widget.theme.textSec),
          )),
        ]),
      ),
    );
  }
}

// ─── Modal nuevo usuario ───────────────────────────────────────────────────────
class _NuevoUsuarioModal extends StatefulWidget {
  const _NuevoUsuarioModal({required this.onCreate});
  final Future<void> Function(String nombre, String apellido, RolUsuario rol, String? turno) onCreate;

  @override
  State<_NuevoUsuarioModal> createState() => _NuevoUsuarioModalState();
}

class _NuevoUsuarioModalState extends State<_NuevoUsuarioModal> {
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  RolUsuario _rol  = RolUsuario.preceptor;
  String _turno    = 'Turno Mañana';
  bool _loading    = false;
  String? _error;

  String get _usernamePreview =>
      _apellidoCtrl.text.isNotEmpty && _nombreCtrl.text.isNotEmpty
          ? Usuario.generarUsername(_apellidoCtrl.text, _nombreCtrl.text)
          : '';

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nombreCtrl.text.isEmpty || _apellidoCtrl.text.isEmpty) {
      setState(() => _error = 'Completá nombre y apellido.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onCreate(
        _nombreCtrl.text.trim(),
        _apellidoCtrl.text.trim(),
        _rol,
        _rol == RolUsuario.preceptor ? _turno : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AAMColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AAMColors.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_add_outlined, size: 18, color: AAMColors.white),
            ),
            const SizedBox(width: 12),
            Text('Nuevo usuario',
              style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AAMColors.primary)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: AAMColors.surface, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, size: 16, color: AAMColors.textSec),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Apellido
          _label('Apellido'),
          const SizedBox(height: 6),
          _input(_apellidoCtrl, 'Ej: Rodríguez'),
          const SizedBox(height: 14),

          // Nombre
          _label('Nombre'),
          const SizedBox(height: 6),
          _input(_nombreCtrl, 'Ej: María'),
          const SizedBox(height: 14),

          // Rol
          _label('Rol'),
          const SizedBox(height: 6),
          _dropdown<RolUsuario>(
            value: _rol,
            items: RolUsuario.values,
            labelOf: (r) => r.label,
            onChanged: (v) => setState(() => _rol = v ?? _rol),
          ),
          const SizedBox(height: 14),

          // Turno (solo si es preceptor)
          if (_rol == RolUsuario.preceptor) ...[
            _label('Turno'),
            const SizedBox(height: 6),
            _dropdown<String>(
              value: _turno,
              items: const ['Turno Mañana', 'Turno Tarde', 'Turno Vespertino'],
              labelOf: (s) => s,
              onChanged: (v) => setState(() => _turno = v ?? _turno),
            ),
            const SizedBox(height: 14),
          ],

          // Preview usuario generado
          if (_usernamePreview.isNotEmpty) ...[
            _label('Usuario generado'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AAMColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AAMColors.accent.withAlpha((0.4 * 255).round())),
              ),
              child: Row(children: [
                Text(_usernamePreview,
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AAMColors.primary)),
                const Spacer(),
                const Icon(Icons.auto_awesome, size: 14, color: AAMColors.accent),
              ]),
            ),
            const SizedBox(height: 6),
            Text('La contraseña inicial se genera automáticamente.',
              style: GoogleFonts.dmSans(fontSize: 11, color: AAMColors.textSec)),
          ],

          // Error
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AAMColors.danger.withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 14, color: AAMColors.danger),
                const SizedBox(width: 8),
                Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger)),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // Botones
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AAMColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text('Cancelar',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.textSec))),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _loading ? AAMColors.accent.withAlpha((0.6 * 255).round()) : AAMColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                    : Text('Crear usuario',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text,
    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AAMColors.textSec));

  Widget _input(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.primary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?) onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        isExpanded: true,
        style: GoogleFonts.dmSans(fontSize: 14, color: AAMColors.primary),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(labelOf(i)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}