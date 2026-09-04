import 'dart:async';
import 'package:flutter/widgets.dart';

/// Refresco periódico en segundo plano — todas las secciones del panel
/// vuelven a pedir sus datos cada [autoRefreshInterval] sin que el usuario
/// tenga que hacer nada. Los formularios de alta/edición son diálogos
/// aparte con su propio estado (`showDialog`), así que este refresco de
/// fondo no los interrumpe.
///
/// Importante: [onAutoRefresh] tiene que actualizar los datos SIN mostrar
/// la pantalla de carga — si el método de carga existente hace
/// `setState(() => _loading = true)` antes de pedir los datos, cada tick
/// va a tapar el contenido con un spinner. Por eso las pantallas que usan
/// este mixin cargan con un parámetro `silent` que se saltea ese flash.
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  static const autoRefreshInterval = Duration(seconds: 30);
  Timer? _autoRefreshTimer;

  /// Qué pedir en cada tick — implementalo en el State que use este mixin.
  void onAutoRefresh();

  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(autoRefreshInterval, (_) {
      if (mounted) onAutoRefresh();
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
