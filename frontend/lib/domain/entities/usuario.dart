/// Entidad de dominio: Usuario del sistema (preceptor o dirección)
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.username,
    required this.rol,
    required this.turno,
    required this.activo,
  });

  final String id;
  final String nombre;
  final String apellido;
  final String username; // formato abc.xxx generado automáticamente
  final RolUsuario rol;
  final String? turno;  // solo para PRECEPTOR
  final bool activo;

  String get nombreCompleto => '$apellido, $nombre';

  /// Genera username automático a partir del nombre completo
  /// Ej: "Rodríguez, María" → "rod.mar"
  static String generarUsername(String apellido, String nombre) {
    String limpiar(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z]'), '');

    final a = limpiar(apellido);
    final n = limpiar(nombre);
    final parteA = a.length >= 3 ? a.substring(0, 3) : a;
    final parteN = n.length >= 3 ? n.substring(0, 3) : n;
    return '$parteA.$parteN';
  }

  Usuario copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? username,
    RolUsuario? rol,
    String? turno,
    bool? activo,
  }) {
    return Usuario(
      id:       id       ?? this.id,
      nombre:   nombre   ?? this.nombre,
      apellido: apellido ?? this.apellido,
      username: username ?? this.username,
      rol:      rol      ?? this.rol,
      turno:    turno    ?? this.turno,
      activo:   activo   ?? this.activo,
    );
  }
}

enum RolUsuario { direccion, preceptor }

extension RolUsuarioLabel on RolUsuario {
  String get label {
    switch (this) {
      case RolUsuario.direccion:  return 'DIRECCIÓN';
      case RolUsuario.preceptor:  return 'PRECEPTOR';
    }
  }
}
