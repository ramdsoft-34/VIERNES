import 'package:viernes/features/alerts/domain/notification_ids.dart';
import 'package:viernes/features/alerts/domain/planned_alert.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';

/// Decide cuándo y cómo avisar de un recordatorio. Lógica pura: no programa
/// nada, solo calcula el plan.
abstract final class AlertPlanner {
  /// Reglas:
  /// - Aviso principal en el próximo momento de aviso (o al terminar el
  ///   aplazamiento).
  /// - Si está activada la insistencia, vuelve a avisar 10, 30 y 60 minutos
  ///   después mientras no se confirme. La última insistencia suena hasta
  ///   que se atienda.
  /// - En horario de silencio, lo no urgente avisa sin sonido y no insiste.
  /// - Solo se programan avisos futuros: si el principal ya pasó (por ejemplo,
  ///   el teléfono estaba apagado), quedan las insistencias pendientes.
  static List<PlannedAlert> plan(
    Reminder reminder,
    AppSettings settings,
    DateTime now,
  ) {
    if (!reminder.isActive) return const [];

    final trigger = reminder.nextTriggerAt;
    final urgent = reminder.priority == ReminderPriority.urgent;
    final steps = settings.escalationEnabled
        ? AppSettings.escalationSteps
        : const <Duration>[];
    final lastStep = steps.length;

    final alerts = <PlannedAlert>[];
    for (var step = 0; step <= lastStep; step++) {
      final at = step == 0 ? trigger : trigger.add(steps[step - 1]);
      if (!at.isAfter(now)) continue;
      final quiet = settings.isQuietAt(at) && !urgent;
      if (quiet && step > 0) continue;
      alerts.add(
        PlannedAlert(
          notificationId: NotificationIds.forReminder(reminder.id, step),
          reminderId: reminder.id,
          at: at,
          step: step,
          silent: quiet,
          fullScreen: settings.fullScreenAlerts && !quiet,
          urgent: urgent,
          insistent: !quiet && (urgent || (step == lastStep && step > 0)),
        ),
      );
    }
    return alerts;
  }
}
