import 'package:viernes/core/error/failure.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';

/// Elimina un recordatorio y devuelve la copia borrada para poder deshacer
/// con [RestoreReminder].
class DeleteReminder {
  const DeleteReminder(this._repository, this._clock);

  final ReminderRepository _repository;
  final Clock _clock;

  Future<Result<Reminder>> call(String id) async {
    final current = await _repository.findById(id);
    if (current == null) {
      return const Result.err(NotFoundFailure('El recordatorio ya no existe'));
    }
    return guardStorage(() async {
      await _repository.delete(
        id,
        event: ReminderEvent(
          reminderId: current.id,
          reminderTitle: current.title,
          type: ReminderEventType.deleted,
          occurredAt: _clock.now(),
        ),
      );
      return current;
    });
  }
}

class RestoreReminder {
  const RestoreReminder(this._repository, this._clock);

  final ReminderRepository _repository;
  final Clock _clock;

  Future<Result<Reminder>> call(Reminder deleted) => guardStorage(() async {
    await _repository.save(
      deleted,
      event: ReminderEvent(
        reminderId: deleted.id,
        reminderTitle: deleted.title,
        type: ReminderEventType.restored,
        occurredAt: _clock.now(),
      ),
    );
    return deleted;
  });
}
