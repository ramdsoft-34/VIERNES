import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

/// "¿Las paso a mañana?": mueve los pendientes vencidos al día siguiente, a la
/// misma hora. Los que se repiten no se mueven: ya volverán solos.
class MoveOverdueToTomorrow {
  const MoveOverdueToTomorrow(this._repository, this._clock);

  final ReminderRepository _repository;
  final Clock _clock;

  /// Devuelve cuántos recordatorios se movieron.
  Future<Result<int>> call() => guardStorage(() async {
    final now = _clock.now();
    final active = await _repository.watchByStatus({
      ReminderStatus.pending,
      ReminderStatus.snoozed,
    }).first;
    final tomorrow = now.startOfDay.addDays(1);
    var moved = 0;
    for (final reminder in active) {
      if (reminder.recurrence.repeats || !reminder.isOverdue(now)) continue;
      final updated = reminder.copyWith(
        dueAt: tomorrow.withTime(reminder.dueAt.hour, reminder.dueAt.minute),
        status: ReminderStatus.pending,
        snoozedUntil: null,
        snoozeCount: 0,
        updatedAt: now,
      );
      await _repository.save(
        updated,
        event: ReminderEvent(
          reminderId: reminder.id,
          reminderTitle: reminder.title,
          type: ReminderEventType.updated,
          occurredAt: now,
        ),
      );
      moved++;
    }
    return moved;
  });
}
