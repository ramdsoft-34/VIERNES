/// Rutas de la app en un solo lugar. Las notificaciones (fase de alertas)
/// abrirán estas mismas rutas.
abstract final class AppRoutes {
  static const home = '/inicio';
  static const reminders = '/recordatorios';
  static const calendar = '/calendario';
  static const history = '/historial';
  static const settings = '/ajustes';

  static const newReminderPath = '/recordatorio/nuevo';
  static const editReminderPath = '/recordatorio/:id';

  static String newReminder({DateTime? date}) => date == null
      ? newReminderPath
      : '$newReminderPath?fecha=${date.year}-${date.month}-${date.day}';

  static String editReminder(String id) => '/recordatorio/$id';

  static const learning = '/aprendizaje';

  static const sharing = '/compartir';
  static const sharedListPath = '/lista/:id';
  static String sharedList(String id) => '/lista/$id';

  static const places = '/lugares';
  static const locationReminders = '/por-ubicacion';

  /// Primera apertura: invitación a iniciar sesión.
  static const welcome = '/bienvenida';

  static const alertPath = '/alerta/:id';

  /// Alerta a pantalla completa de un recordatorio.
  static String alert(String reminderId) => '/alerta/$reminderId';

  static DateTime? parseDateParam(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.contains(null)) return null;
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }
}
