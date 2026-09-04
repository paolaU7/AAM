import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/create_user.dart';
import '../../infrastructure/datasources/api_datasource.dart';
import '../../infrastructure/repositories/user_repository_impl.dart';
import '../widgets/aam_design_system.dart';
import '../widgets/auto_refresh_mixin.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> with AutoRefreshMixin<UsuariosScreen> {
  late final UserRepositoryImpl _repo;
  late final CreateUser _crearUsuario;

  List<User>? _usuarios;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo         = UserRepositoryImpl(ApiDatasource());
    _crearUsuario = CreateUser(_repo);
    _cargar();
    startAutoRefresh();
  }

  @override
  void onAutoRefresh() => _cargar(silent: true);

  Future<void> _cargar({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await _repo.getUsers();
      if (mounted) setState(() { _usuarios = data; _error = null; });
    } catch (_) {
      if (mounted && !silent) setState(() => _error = 'Error al cargar usuarios');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _refresh() => _cargar();

  void _abrirModal() {
    showDialog<CreatedUser>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _NuevoUsuarioModal(
        onCreate: (firstName, lastName, role) => _crearUsuario(
          firstName: firstName,
          lastName:  lastName,
          role:      role,
        ),
      ),
    ).then((created) {
      _refresh();
      if (created != null) _mostrarPasswordGenerada(created);
    });
  }

  void _mostrarPasswordGenerada(CreatedUser created) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _PasswordGeneradaModal(usuario: created.user, password: created.temporaryPassword),
    );
  }

  Future<void> _abrirEdicion(User usuario) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
      builder: (_) => _EditarUsuarioModal(
        usuario: usuario,
        onSave: (nombre, apellido, rol) => _repo.updateUser(
          id: usuario.id, firstName: nombre, lastName: apellido, role: rol,
        ),
      ),
    );
    if (result == true) _refresh();
  }

  Future<void> _eliminarUsuario(User usuario) async {
    final ok = await _confirmarEliminacion(
      context,
      titulo: 'Eliminar usuario',
      mensaje: '¿Eliminar a ${usuario.fullName}? Esta acción no se puede deshacer. '
          'Si tiene asistencias, asignaciones u horarios asociados, no va a poder eliminarse — '
          'desactivalo en su lugar.',
    );
    if (!ok) return;
    try {
      await _repo.deleteUser(usuario.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
          builder: (_) => _ErrorModal(mensaje: e.toString()),
        );
      }
    }
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
          child: _loading && _usuarios == null
              ? const AAMLoadingScreen()
              : _error != null && _usuarios == null
                  ? AAMErrorWidget(message: _error!, onRetry: _refresh)
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        _buildBanner(theme),
                        const SizedBox(height: 20),
                        Expanded(child: _buildTabla(_usuarios ?? [], theme)),
                      ]),
                    ),
        ),
      ],
    );
  }

  Widget _buildBanner(AAMTheme theme) {
    // AAMColors.mint es un fondo fijo y claro que no sigue el tema — en modo
    // oscuro quedaba un tinte apagado con texto igual de oscuro encima
    // (bajo contraste). Se reemplaza por un tinte de accent con más opacidad
    // en modo oscuro, y el texto/ícono siguen theme.text.
    final bgAlpha = theme.isDark ? 0.18 : 0.12;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AAMColors.accent.withAlpha((bgAlpha * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AAMColors.accent.withAlpha((0.3 * 255).round())),
      ),
      child: Row(children: [
        Icon(Icons.shield_outlined, size: 18, color: theme.text),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Solo dirección puede crear y gestionar cuentas. '
          'Los usuarios se generan automáticamente en formato apellido.nombre.',
          style: GoogleFonts.dmSans(fontSize: 13, color: theme.text),
        )),
      ]),
    );
  }

  Widget _buildTabla(List<User> usuarios, AAMTheme theme) {
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
          ('Email',   2),
          ('Estado',  2),
          ('',        2),
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
                      await _repo.toggleActive(usuarios[i].id);
                      _refresh();
                    },
                    onEdit: () => _abrirEdicion(usuarios[i]),
                    onDelete: () => _eliminarUsuario(usuarios[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ─── Fila de usuario ──────────────────────────────────────────────────────────
class _UsuarioRow extends StatefulWidget {
  const _UsuarioRow({
    required this.usuario,
    required this.theme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final User usuario;
  final AAMTheme theme;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_UsuarioRow> createState() => _UsuarioRowState();
}

class _UsuarioRowState extends State<_UsuarioRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    final isDireccion = u.role == UserRole.principal;

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
              child: Text(u.lastName.substring(0, 1),
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                  color: isDireccion ? AAMColors.white : AAMColors.primary)),
            ),
            const SizedBox(width: 10),
            Text(u.fullName,
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
            label: u.role.label,
            color: isDireccion ? AAMColors.primary : AAMColors.accent,
          )),
          Expanded(flex: 2, child: Text(u.email,
            style: GoogleFonts.dmSans(fontSize: 13, color: widget.theme.textSec))),
          Expanded(flex: 2, child: AAMBadge(
            label: u.isActive ? 'Activo' : 'Inactivo',
            color: u.isActive ? AAMColors.success : AAMColors.textSec,
          )),
          // Acciones — Dirección solo puede editarse (no se puede deshabilitar
          // ni eliminar la propia cuenta de admin desde acá, para evitar
          // quedarse sin acceso).
          Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _RowActionBtn(icon: Icons.edit_outlined, tooltip: 'Editar usuario', color: AAMColors.accent, onTap: widget.onEdit),
            if (!isDireccion) ...[
              const SizedBox(width: 10),
              _RowActionBtn(
                icon: u.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                tooltip: u.isActive ? 'Deshabilitar' : 'Reactivar',
                color: u.isActive ? AAMColors.highlight : AAMColors.success,
                onTap: widget.onToggle,
              ),
              const SizedBox(width: 10),
              _RowActionBtn(icon: Icons.delete_outline, tooltip: 'Eliminar usuario', color: AAMColors.danger, onTap: widget.onDelete),
            ],
          ])),
        ]),
      ),
    );
  }
}

class _RowActionBtn extends StatefulWidget {
  const _RowActionBtn({required this.icon, required this.tooltip, required this.color, required this.onTap});
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_RowActionBtn> createState() => _RowActionBtnState();
}

class _RowActionBtnState extends State<_RowActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Icon(widget.icon, size: 16, color: _hovered ? widget.color : AAMColors.textSec),
        ),
      ),
    );
  }
}

// ─── Modal nuevo usuario ───────────────────────────────────────────────────────
class _NuevoUsuarioModal extends StatefulWidget {
  const _NuevoUsuarioModal({required this.onCreate});
  final Future<CreatedUser> Function(String nombre, String apellido, UserRole rol) onCreate;

  @override
  State<_NuevoUsuarioModal> createState() => _NuevoUsuarioModalState();
}

class _NuevoUsuarioModalState extends State<_NuevoUsuarioModal> {
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  UserRole _rol  = UserRole.preceptor;
  bool _loading    = false;
  String? _error;

  String get _usernamePreview =>
      _apellidoCtrl.text.isNotEmpty && _nombreCtrl.text.isNotEmpty
          ? User.generateUsername(_apellidoCtrl.text, _nombreCtrl.text)
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
      final created = await widget.onCreate(
        _nombreCtrl.text.trim(),
        _apellidoCtrl.text.trim(),
        _rol,
      );
      if (mounted) Navigator.of(context).pop(created);
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
          _dropdown<UserRole>(
            value: _rol,
            items: UserRole.values,
            labelOf: (r) => r.label,
            onChanged: (v) => setState(() => _rol = v ?? _rol),
          ),
          const SizedBox(height: 14),

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
      child: AAMDropdown<T>(
        value: value,
        options: items,
        itemLabel: labelOf,
        isExpanded: true,
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Contraseña generada (se muestra una única vez) ────────────────────────────
class _PasswordGeneradaModal extends StatelessWidget {
  const _PasswordGeneradaModal({required this.usuario, required this.password});
  final User usuario;
  final String password;

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
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AAMColors.success, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check, size: 18, color: AAMColors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Usuario creado',
              style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AAMColors.primary))),
          ]),
          const SizedBox(height: 20),
          Text('${usuario.fullName} (${usuario.email})',
            style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec)),
          const SizedBox(height: 16),
          Text('Contraseña inicial — anotala ahora, no se puede volver a ver:',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AAMColors.textSec)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AAMColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AAMColors.accent.withAlpha((0.4 * 255).round())),
            ),
            child: Text(password,
              style: const TextStyle(fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AAMColors.primary)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('Listo',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Modal editar usuario ───────────────────────────────────────────────────────
class _EditarUsuarioModal extends StatefulWidget {
  const _EditarUsuarioModal({required this.usuario, required this.onSave});
  final User usuario;
  final Future<User> Function(String nombre, String apellido, UserRole rol) onSave;

  @override
  State<_EditarUsuarioModal> createState() => _EditarUsuarioModalState();
}

class _EditarUsuarioModalState extends State<_EditarUsuarioModal> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late UserRole _rol;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.usuario.firstName);
    _apellidoCtrl = TextEditingController(text: widget.usuario.lastName);
    _rol = widget.usuario.role;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nombreCtrl.text.trim().isEmpty || _apellidoCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Completá nombre y apellido.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onSave(_nombreCtrl.text.trim(), _apellidoCtrl.text.trim(), _rol);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
            width: 420,
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
                  decoration: BoxDecoration(color: AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined, size: 18, color: AAMColors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Editar usuario',
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
              _FieldLabel(theme: theme, text: 'Apellido'),
              const SizedBox(height: 6),
              _FieldInput(theme: theme, controller: _apellidoCtrl, hint: 'Ej: Rodríguez'),
              const SizedBox(height: 14),
              _FieldLabel(theme: theme, text: 'Nombre'),
              const SizedBox(height: 6),
              _FieldInput(theme: theme, controller: _nombreCtrl, hint: 'Ej: María'),
              const SizedBox(height: 14),
              _FieldLabel(theme: theme, text: 'Rol'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                child: AAMDropdown<UserRole>(
                  value: _rol,
                  options: UserRole.values,
                  itemLabel: (r) => r.label,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _rol = v ?? _rol),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AAMColors.danger.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 14, color: AAMColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.danger))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textSec))),
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
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AAMColors.white, strokeWidth: 2))
                        : Text('Guardar cambios', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
                  ),
                )),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.theme, required this.text});
  final AAMTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSec));
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({required this.theme, required this.controller, required this.hint});
  final AAMTheme theme;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
      child: TextField(
        controller: controller,
        style: GoogleFonts.dmSans(fontSize: 14, color: theme.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }
}

// ─── Confirmación de borrado ──────────────────────────────────────────────────
Future<bool> _confirmarEliminacion(BuildContext context, {required String titulo, required String mensaje}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withAlpha((0.4 * 255).round()),
    builder: (_) => _ConfirmDialog(titulo: titulo, mensaje: mensaje),
  );
  return result == true;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.titulo, required this.mensaje});
  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text)),
              const SizedBox(height: 10),
              Text(mensaje, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: theme.borderCol), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Cancelar', style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AAMColors.danger, borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Eliminar', style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.white))),
                  ),
                )),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ─── Error genérico (p.ej. borrado rechazado por registros asociados) ─────────
class _ErrorModal extends StatelessWidget {
  const _ErrorModal({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AAMTheme(),
      builder: (context, _) {
        final theme = AAMTheme();
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.error_outline, size: 20, color: AAMColors.danger),
                const SizedBox(width: 10),
                Expanded(child: Text('No se pudo completar la acción',
                  style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: theme.text))),
              ]),
              const SizedBox(height: 10),
              Text(mensaje, style: GoogleFonts.dmSans(fontSize: 13, color: theme.textSec)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AAMColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Entendido', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AAMColors.white))),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}