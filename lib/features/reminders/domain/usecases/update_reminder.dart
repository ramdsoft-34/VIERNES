import 'package:viernes/core/error/failure.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:viernes/features/reminders/domain/usecases/reminder_validator.dart';

class UpdateReminder {
  const UpdateReminder(this._repository, this._clock);

  final ReminderRepository _repository;
  final Clock _clock;

  Future<Result<Reminder>> call(Reminder edited) async {
    final now = _clock.now();
    final current = await _repository.findById(edited.id);
    if (current == null) {
      return const Result.err(NotFoundFailure('El recordatorio ya no existe'));
    }

    final scheduleChanged =
        edited.dueAt != current.dueAt || edited.leadTime != current.leadTime;
    final failure = ReminderValidator.validate(
      title: edited.title,
      dueAt: edited.dueAt,
      leadTime: edited.leadTime,
      now: now,
      // Editar solo el texto de algo vencido no debe exigir otra fecha.
      checkPast: scheduleChanged,
    );
    if (failure != null) return Result.err(failure);

    // Una nueva hora reemplaza cualquier aplazamiento anterior.
    final reschedule = scheduleChanged && current.isActive;
    final updated = edited.copyWith(
      title: edited.title.trim(),
      updatedAt: now,
      status: reschedule ? ReminderStatus.pending : null,
      snoozedUntil: reschedule ? null : edited.snoozedUntil,
      snoozeCount: reschedule ? 0 : null,
    );

    return guardStorage(() async {
      await _repository.save(
        updated,
        event: ReminderEvent(
          reminderId: updated.id,
          reminderTitle: updated.title,
          type: ReminderEventType.updated,
          occurredAt: now,
        ),
      );
      return updated;
    });
  }
}
