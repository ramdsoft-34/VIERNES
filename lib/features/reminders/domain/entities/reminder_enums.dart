// Los valores `name` de estos enums se guardan en la base de datos.
// No renombrar sin una migración.

enum ReminderStatus {
  /// Esperando su momento o ya vencido sin confirmar.
  pending,

  /// El usuario pidió que se le recordara más tarde.
  snoozed,

  /// El usuario confirmó que la realizó.
  completed,
}

enum ReminderPriority {
  low,
  normal,
  high,
  urgent;

  bool get isAtLeastHigh => index >= ReminderPriority.high.index;
}

enum ReminderCategory { personal, work, study, health, home, finance, other }

/// Cómo se creó el recordatorio. Sirve para medir la calidad del asistente.
/// `shared`: llegó de otra persona («recuérdale a Sofi…»).
enum ReminderSource { manual, voice, shared }

enum ReminderEventType {
  created,
  updated,
  completed,
  snoozed,
  reopened,
  deleted,
  restored,

  /// Reservados para la fase de alertas.
  notified,
  escalated,
}
