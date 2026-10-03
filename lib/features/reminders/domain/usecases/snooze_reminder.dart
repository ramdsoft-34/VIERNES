import 'package:viernes/core/error/failure.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

/// El usuario responde "Todavía no" / "Recuérdamelo después".
class SnoozeReminder {
  const SnoozeReminder(this._repository, this._clock);

  final ReminderRepository _repository;
  final Clock _clock;

  static const maxDelay = Duration(days: 7);

  Future<Result<Reminder>> call(String id, Duration delay) async {
    if (delay <= Duration.zero || delay > maxDelay) {
      return const Result.err(
        ValidationFailure('Puedo posponerlo entre 1 minuto y 7 días'),
      );
    }
    final now = _clock.now();
    final current = await _repository.findById(id);
    if (current == null) {
      return const Result.err(NotFoundFailure('El recordatorio ya no existe'));
    }
    if (!current.isActive) {
      return const Result.err(
        ValidationFailure('No se puede posponer algo ya completado'),
      );
    }

    final updated = current.copyWith(
      status: ReminderStatus.snoozed,
      snoozedUntil: now.add(delay),
      snoozeCount: current.snoozeCount + 1,
      updatedAt: now,
    );

    return guardStorage(() async {
      await _repository.save(
        updated,
        event: ReminderEvent(
          reminderId: current.id,
          reminderTitle: current.title,
          type: ReminderEventType.snoozed,
          occurredAt: now,
        ),
      );
      return updated;
    });
  }
}
