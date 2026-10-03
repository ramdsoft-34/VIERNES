import 'package:viernes/core/error/result.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/move_overdue_to_tomorrow.dart';
import 'package:viernes/features/reminders/domain/usecases/snooze_reminder.dart';

/// Botones de las notificaciones.
abstract final class AlertActions {
  static const complete = 'complete';
  static const snooze = 'snooze';

  /// Resumen de la noche: pasar lo pendiente a mañana.
  static const moveToTomorrow = 'move_tomorrow';

  /// Resumen de la mañana: abrir la app y leerlo en voz alta.
  static const listenSummary = 'listen_summary';

  /// Prefijo del payload de los resúmenes diarios.
  static const summaryPayloadPrefix = 'summary:';

  /// Payload del resumen de la mañana.
  static const morningPayload = 'summary:morning';
}

/// Atiende los botones de las notificaciones.
///
/// Se usa igual con la app abierta o cerrada (en segundo plano), por eso no
/// depende de Flutter ni de Riverpod.
class AlertActionHandler {
  const AlertActionHandler({
    required this._complete,
    required this._snooze,
    required this._snoozeDuration,
    this._moveOverdue,
  });

  final CompleteReminder _complete;
  final SnoozeReminder _snooze;
  final Duration Function() _snoozeDuration;
  final MoveOverdueToTomorrow? _moveOverdue;

  /// "Ya lo hice" / "Recordar después". Devuelve el recordatorio actualizado,
  /// o `null` si la acción no aplica.
  Future<Reminder?> handle({
    required String? actionId,
    required String? reminderId,
  }) async {
    if (reminderId == null || reminderId.isEmpty) return null;
    final Result<Reminder> result;
    switch (actionId) {
      case AlertActions.complete:
        result = await _complete(reminderId);
      case AlertActions.snooze:
        result = await _snooze(reminderId, _snoozeDuration());
      default:
        return null;
    }
    return result.valueOrNull;
  }

  /// "Pasar a mañana" del resumen de la noche. Devuelve cuántos se movieron.
  Future<int?> handleSummaryAction(String? actionId) async {
    final move = _moveOverdue;
    if (actionId != AlertActions.moveToTomorrow || move == null) return null;
    return (await move()).valueOrNull;
  }
}
