import 'package:viernes/core/error/failure.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

/// El usuario confirma "Sí, ya lo hice".
///
/// Si el recordatorio se repite, la ocurrencia queda registrada en el
/// historial y el recordatorio avanza a la siguiente ocurrencia futura.
class CompleteReminder {
  const CompleteReminder(this._repository, this._clock);

  final ReminderRepository _repository;
  final Clock _clock;

  Future<Result<Reminder>> call(String id) async {
    final now = _clock.now();
    final current = await _repository.findById(id);
    if (current == null) {
      return const Result.err(NotFoundFailure('El recordatorio ya no existe'));
    }
    if (!current.isActive) {
      return const Result.err(
        ValidationFailure('Este recordatorio ya estaba completado'),
      );
    }

    final event = ReminderEvent(
      reminderId: current.id,
      reminderTitle: current.title,
      type: ReminderEventType.completed,
      occurredAt: now,
      onTime: !now.isAfter(current.dueAt),
    );

    final updated = current.recurrence.repeats
        ? current.copyWith(
            dueAt: _nextFutureOccurrence(current, now),
            status: ReminderStatus.pending,
            snoozedUntil: null,
            snoozeCount: 0,
            updatedAt: now,
          )
        : current.copyWith(
            status: ReminderStatus.completed,
            snoozedUntil: null,
            completedAt: now,
            updatedAt: now,
          );

    return guardStorage(() async {
      await _repository.save(updated, event: event);
      return updated;
    });
  }

  /// Deshace la confirmación restaurando el estado [previous] y quitando el
  /// evento de completado del historial.
  Future<Result<Reminder>> undo(Reminder previous) => guardStorage(() async {
    await _repository.revert(
      previous,
      undoneEvent: ReminderEventType.completed,
    );
    return previous;
  });

  /// Salta las ocurrencias cuyo aviso ya pasó (p. ej. si se confirma tarde).
  DateTime _nextFutureOccurrence(Reminder reminder, DateTime now) {
    var due = reminder.recurrence.nextAfter(reminder.dueAt)!;
    while (!due.subtract(reminder.leadTime).isAfter(now)) {
      due = reminder.recurrence.nextAfter(due)!;
    }
    return due;
  }
}
