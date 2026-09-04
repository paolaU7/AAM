/// Domain entity: AppNotification
///
/// Alerta calculada al vuelo por el backend para el panel de
/// notificaciones (campana del header) — no se persiste ni tiene estado
/// de leído/no leído, se recalcula cada vez que se abre el desplegable.
class AppNotification {
  const AppNotification({required this.type, required this.message});

  final String type; // 'preceptor_temp_assignment' | 'schedule_exception' | 'consecutive_absences'
  final String message;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        type: json['type'],
        message: json['message'],
      );
}
