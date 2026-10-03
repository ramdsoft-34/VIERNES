import 'package:viernes/core/error/failure.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

/// Devuelve a pendiente un recordatorio marcado como hecho por error.
class ReopenReminder {
  const ReopenReminder(this._repository, this._clock);

  final ReminderRepository _repository;
  final Clock _clock;

  Future<Result<Reminder>> call(String id) async {
    final now = _clock.now();
    final current = await _repository.findById(id);
    if (current == null) {
      return const Result.err(NotFoundFailure('El recordatorio ya no existe'));
    }
    if (current.isActive) return Result.ok(current);

    final updated = current.copyWith(
      status: ReminderStatus.pending,
      completedAt: null,
      snoozedUntil: null,
      snoozeCount: 0,
      updatedAt: now,
    );
    return guardStorage(() async {
      await _repository.save(
        updated,
        event: ReminderEvent(
          reminderId: current.id,
          reminderTitle: current.title,
          type: ReminderEventType.reopened,
          occurredAt: now,
        ),
      );
      return updated;
    });
  }
}
