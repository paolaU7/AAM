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
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _repo         = UsuarioRepositoryImpl(MockDatasource());
    _crearUsuario = CrearUsuario(_repo);
    _future       = _repo.getUsuarios();
  }

  void _refresh() => setState(() => _future = _repo.getUsuarios());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AAMTopbar(
          title: 'Usuarios',
          actions: [
            AAMButton(
              label: 'Nuevo usuario',
              icon: Icons.person_add_outlined,
              onPressed: () { setState(() { _showForm = !_showForm; }); },
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Usuario>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const AAMLoadingScreen();
              if (snap.hasError) return AAMErrorWidget(
                message: 'Error al cargar usuarios', onRetry: _refresh,
              );

              return Padding(
                padding: const EdgeInsets.all(32),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: Column(children: [
                    _buildBanner(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildTabla(snap.data!)),
                  ])),
                  if (_showForm) ...[
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 320,
                      child: _NuevoUsuarioForm(
                        onClose: () => setState(() => _showForm = false),
                        onCreate: (nombre, apellido, rol, turno) async {
                          await _crearUsuario(
                            nombre:   nombre,
                            apellido: apellido,
                            rol:      rol,
                            turno:    turno,
                          );
                          setState(() => _showForm = false);
                          _refresh();
                        },
                      ),
                    ),
                  ],
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
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

  Widget _buildTabla(List<Usuario> usuarios) {
    return Container(
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const AAMTableHeader(columns: [
          ('Nombre',    2),
          ('Usuario',   2),
          ('Rol',       2),
          ('Turno',     2),
          ('Estado',    2),
          ('',          1),
        ]),
        Expanded(
          child: ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (ctx, i) => _UsuarioRow(
              usuario: usuarios[i],
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
  const _UsuarioRow({required this.usuario, required this.onToggle});
  final Usuario usuario;
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
          color: _hovered ? AAMColors.surface : AAMColors.white,
          border: const Border(bottom: BorderSide(color: AAMColors.border, width: 1)),
        ),
        child: Row(children: [
          // Nombre
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
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AAMColors.primary)),
          ])),
          // Username (monospace)
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AAMColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(u.username,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AAMColors.primary)),
          )),
          // Rol
          Expanded(flex: 2, child: AAMBadge(
            label: u.rol.label,
            color: isDireccion ? AAMColors.primary : AAMColors.accent,
          )),
          // Turno
          Expanded(flex: 2, child: Text(u.turno ?? '—',
            style: GoogleFonts.dmSans(fontSize: 13, color: AAMColors.textSec))),
          // Estado
          Expanded(flex: 2, child: AAMBadge(
            label: u.activo ? 'Activo' : 'Inactivo',
            color: u.activo ? AAMColors.success : AAMColors.textSec,
          )),
          // Acciones
          Expanded(flex: 1, child: Row(children: [
            GestureDetector(
              onTap: widget.onToggle,
              child: Icon(Icons.block_outlined, size: 15,
                color: _hovered ? AAMColors.highlight : AAMColors.textSec),
            ),
          ])),
        ]),
      ),
    );
  }
}

// ─── Formulario nuevo usuario ─────────────────────────────────────────────────
class _NuevoUsuarioForm extends StatefulWidget {
  const _NuevoUsuarioForm({required this.onClose, required this.onCreate});
  final VoidCallback onClose;
  final Future<void> Function(String nombre, String apellido, RolUsuario rol, String? turno) onCreate;

  @override
  State<_NuevoUsuarioForm> createState() => _NuevoUsuarioFormState();
}

class _NuevoUsuarioFormState extends State<_NuevoUsuarioForm> {
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  RolUsuario _rol   = RolUsuario.preceptor;
  String _turno     = 'Turno Mañana';
  bool _loading     = false;
  String? _error;

  String get _usernamePreview =>
      _apellidoCtrl.text.isNotEmpty && _nombreCtrl.text.isNotEmpty
          ? Usuario.generarUsername(_apellidoCtrl.text, _nombreCtrl.text)
          : '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AAMColors.white,
        border: Border.all(color: AAMColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Nuevo usuario',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AAMColors.primary)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: const Icon(Icons.close, size: 18, color: AAMColors.textSec),
          ),
        ]),
        const SizedBox(height: 20),

        _label('Apellido'),
        const SizedBox(height: 6),
        _input(_apellidoCtrl, 'Ej: Rodríguez'),
        const SizedBox(height: 14),

        _label('Nombre'),
        const SizedBox(height: 6),
        _input(_nombreCtrl, 'Ej: María'),
        const SizedBox(height: 14),

        _label('Rol'),
        const SizedBox(height: 6),
        _dropdown<RolUsuario>(
          value: _rol,
          items: RolUsuario.values,
          labelOf: (r) => r.label,
          onChanged: (v) { setState(() { _rol = v ?? _rol; }); },
        ),
        const SizedBox(height: 14),

        if (_rol == RolUsuario.preceptor) ...[
          _label('Turno'),
          const SizedBox(height: 6),
          _dropdown<String>(
            value: _turno,
            items: const ['Turno Mañana', 'Turno Tarde', 'Turno Vespertino'],
            labelOf: (s) => s,
            onChanged: (v) { setState(() { _turno = v ?? _turno; }); },
          ),
          const SizedBox(height: 14),
        ],

        if (_usernamePreview.isNotEmpty) ...[
          _label('Usuario generado'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AAMColors.surface,
              borderRadius: BorderRadius.circular(10),
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

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: AAMColors.highlight)),
        ],

        const SizedBox(height: 20),
        GestureDetector(
          onTap: _loading ? null : _submit,
          child: Container(
            width: double.infinity,
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
        ),
      ]),
    );
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
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _label(String text) => Text(text,
    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AAMColors.textSec));

  Widget _input(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AAMColors.border), borderRadius: BorderRadius.circular(10),
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
        border: Border.all(color: AAMColors.border), borderRadius: BorderRadius.circular(10),
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
