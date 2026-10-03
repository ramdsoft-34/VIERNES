import 'package:viernes/core/utils/id_generator.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

Reminder buildReminder({
  String id = 'r1',
  String title = 'Entregar el informe',
  DateTime? dueAt,
  Duration leadTime = Duration.zero,
  Recurrence recurrence = Recurrence.none,
  ReminderStatus status = ReminderStatus.pending,
  DateTime? snoozedUntil,
  ReminderPriority priority = ReminderPriority.normal,
}) {
  final created = DateTime(2026, 10, 1, 9);
  return Reminder(
    id: id,
    title: title,
    dueAt: dueAt ?? DateTime(2026, 10, 2, 8),
    leadTime: leadTime,
    recurrence: recurrence,
    status: status,
    snoozedUntil: snoozedUntil,
    priority: priority,
    createdAt: created,
    updatedAt: created,
  );
}

class SequentialIds implements IdGenerator {
  var _next = 1;

  @override
  String next() => 'id-${_next++}';
}
