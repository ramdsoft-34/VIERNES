import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

/// Contrato de persistencia de recordatorios.
///
/// Hoy lo implementa una base local (Drift). Una futura sincronización en la
/// nube será otra implementación sin cambios en el dominio ni en la UI.
abstract interface class ReminderRepository {
  /// Recordatorios con alguno de los [statuses], ordenados por próximo aviso.
  Stream<List<Reminder>> watchByStatus(Set<ReminderStatus> statuses);

  /// Recordatorios cuya fecha límite cae en `[from, to)`.
  Stream<List<Reminder>> watchDueBetween(DateTime from, DateTime to);

  Stream<Reminder?> watchById(String id);

  Future<Reminder?> findById(String id);

  /// Inserta o reemplaza el recordatorio y registra [event] en la misma
  /// transacción.
  Future<void> save(Reminder reminder, {ReminderEvent? event});

  Future<void> delete(String id, {ReminderEvent? event});

  /// Deshace una acción: restaura [previous] y elimina el último evento de
  /// tipo [undoneEvent] de ese recordatorio, para que no cuente en las
  /// estadísticas.
  Future<void> revert(
    Reminder previous, {
    required ReminderEventType undoneEvent,
  });

  /// Eventos más recientes primero, opcionalmente filtrados.
  Stream<List<ReminderEvent>> watchEvents({
    Set<ReminderEventType>? types,
    DateTime? since,
  });
}
