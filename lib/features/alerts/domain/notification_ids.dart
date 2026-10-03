/// Ids de notificación deterministas a partir del id del recordatorio.
///
/// `String.hashCode` no está garantizado entre ejecuciones, así que se usa
/// FNV-1a: el mismo recordatorio produce siempre los mismos ids, lo que
/// permite cancelar sus avisos aunque la app se haya reiniciado.
abstract final class NotificationIds {
  /// Aviso principal + insistencias + margen para futuros tipos de aviso.
  static const slotsPerReminder = 8;

  /// Ids reservados (resúmenes de la mañana y la noche, Fase 5).
  static const reservedBase = 0x7FFFFF00;

  static int forReminder(String reminderId, int slot) {
    assert(slot >= 0 && slot < slotsPerReminder, 'slot fuera de rango');
    return _hash(reminderId) * slotsPerReminder + slot;
  }

  static List<int> allFor(String reminderId) => [
    for (var slot = 0; slot < slotsPerReminder; slot++)
      forReminder(reminderId, slot),
  ];

  /// FNV-1a de 32 bits, reducido para que `hash * 8 + slot` quepa en un
  /// entero positivo de 32 bits sin chocar con los ids reservados.
  static int _hash(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % (reservedBase ~/ slotsPerReminder);
  }
}
