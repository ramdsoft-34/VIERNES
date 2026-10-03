import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/alerts/application/reminder_alert_sync.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

/// Decorador: cada cambio guardado reprograma los avisos del recordatorio.
///
/// Así ningún caso de uso (crear, completar, posponer, eliminar…) necesita
/// acordarse de las alarmas, ni en la app ni al responder desde la
/// notificación.
class SchedulingReminderRepository implements ReminderRepository {
  /// `onChanged` se ejecuta tras cada cambio para lo que depende de toda la
  /// agenda (resúmenes diarios y widget).
  SchedulingReminderRepository(
    this._inner,
    this._sync, {
    this._onChanged,
  });

  final ReminderRepository _inner;
  final ReminderAlertSync _sync;
  final Future<void> Function()? _onChanged;

  @override
  Future<void> save(Reminder reminder, {ReminderEvent? event}) async {
    await _inner.save(reminder, event: event);
    await _guard(() => _sync.sync(reminder));
    await _notifyChanged();
  }

  @override
  Future<void> delete(String id, {ReminderEvent? event}) async {
    await _inner.delete(id, event: event);
    await _guard(() => _sync.remove(id));
    await _notifyChanged();
  }

  @override
  Future<void> revert(
    Reminder previous, {
    required ReminderEventType undoneEvent,
  }) async {
    await _inner.revert(previous, undoneEvent: undoneEvent);
    await _guard(() => _sync.sync(previous));
    await _notifyChanged();
  }

  Future<void> _notifyChanged() async {
    final onChanged = _onChanged;
    if (onChanged != null) await _guard(onChanged);
  }

  /// Un fallo al programar no debe deshacer lo guardado; se corrige en la
  /// siguiente sincronización completa.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stack) {
      AppLogger.error(
        'No se pudo programar el aviso',
        error: error,
        stackTrace: stack,
      );
    }
  }

  @override
  Stream<List<Reminder>> watchByStatus(Set<ReminderStatus> statuses) =>
      _inner.watchByStatus(statuses);

  @override
  Stream<List<Reminder>> watchDueBetween(DateTime from, DateTime to) =>
      _inner.watchDueBetween(from, to);

  @override
  Stream<Reminder?> watchById(String id) => _inner.watchById(id);

  @override
  Future<Reminder?> findById(String id) => _inner.findById(id);

  @override
  Stream<List<ReminderEvent>> watchEvents({
    Set<ReminderEventType>? types,
    DateTime? since,
  }) => _inner.watchEvents(types: types, since: since);
}
