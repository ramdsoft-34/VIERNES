import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/core/utils/id_generator.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';
import 'package:viernes/features/reminders/domain/repositories/reminder_repository.dart';
import 'package:viernes/features/reminders/domain/usecases/reminder_validator.dart';

class CreateReminder {
  const CreateReminder(this._repository, this._clock, this._ids);

  final ReminderRepository _repository;
  final Clock _clock;
  final IdGenerator _ids;

  Future<Result<Reminder>> call(ReminderDraft draft) async {
    final now = _clock.now();
    final failure = ReminderValidator.validate(
      title: draft.title,
      dueAt: draft.dueAt,
      leadTime: draft.leadTime,
      now: now,
    );
    if (failure != null) return Result.err(failure);

    final reminder = Reminder(
      id: _ids.next(),
      title: draft.title.trim(),
      notes: _blankToNull(draft.notes),
      dueAt: draft.dueAt,
      leadTime: draft.leadTime,
      recurrence: draft.recurrence,
      priority: draft.priority,
      category: draft.category,
      source: draft.source,
      rawUtterance: draft.rawUtterance,
      nluConfidence: draft.nluConfidence,
      createdAt: now,
      updatedAt: now,
    );

    return guardStorage(() async {
      await _repository.save(
        reminder,
        event: ReminderEvent(
          reminderId: reminder.id,
          reminderTitle: reminder.title,
          type: ReminderEventType.created,
          occurredAt: now,
        ),
      );
      return reminder;
    });
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
