import 'package:drift/drift.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/core/utils/enum_x.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

extension ReminderRowMapper on ReminderRow {
  Reminder toDomain() => Reminder(
    id: id,
    title: title,
    notes: notes,
    dueAt: dueAt,
    leadTime: Duration(minutes: leadTimeMinutes),
    recurrence: Recurrence.decode(recurrence),
    priority: enumByName(
      ReminderPriority.values,
      priority,
      ReminderPriority.normal,
    ),
    category: enumByName(
      ReminderCategory.values,
      category,
      ReminderCategory.other,
    ),
    status: enumByName(ReminderStatus.values, status, ReminderStatus.pending),
    snoozedUntil: snoozedUntil,
    snoozeCount: snoozeCount,
    source: enumByName(ReminderSource.values, source, ReminderSource.manual),
    rawUtterance: rawUtterance,
    nluConfidence: nluConfidence,
    createdAt: createdAt,
    updatedAt: updatedAt,
    completedAt: completedAt,
  );
}

extension ReminderToCompanion on Reminder {
  /// [dirty]: el cambio está pendiente de subir a la cuenta (falso solo al
  /// guardar lo que llega de la nube).
  RemindersCompanion toCompanion({bool dirty = true}) =>
      RemindersCompanion.insert(
        id: id,
        title: title,
        notes: Value(notes),
        dueAt: dueAt,
        leadTimeMinutes: Value(leadTime.inMinutes),
        recurrence: Value(recurrence.repeats ? recurrence.encode() : ''),
        priority: priority.name,
        category: category.name,
        status: status.name,
        snoozedUntil: Value(snoozedUntil),
        snoozeCount: Value(snoozeCount),
        source: source.name,
        rawUtterance: Value(rawUtterance),
        nluConfidence: Value(nluConfidence),
        createdAt: createdAt,
        updatedAt: updatedAt,
        completedAt: Value(completedAt),
        dirty: Value(dirty),
      );
}

extension ReminderEventRowMapper on ReminderEventRow {
  ReminderEvent toDomain() => ReminderEvent(
    id: id,
    reminderId: reminderId,
    reminderTitle: reminderTitle,
    type: enumByName(
      ReminderEventType.values,
      type,
      ReminderEventType.updated,
    ),
    occurredAt: occurredAt,
    onTime: onTime,
    syncId: syncId,
  );
}

extension ReminderEventToCompanion on ReminderEvent {
  ReminderEventsCompanion toCompanion({
    required String syncId,
    bool dirty = true,
  }) => ReminderEventsCompanion.insert(
    reminderId: reminderId,
    reminderTitle: reminderTitle,
    type: type.name,
    occurredAt: occurredAt,
    onTime: Value(onTime),
    syncId: Value(syncId),
    dirty: Value(dirty),
  );
}
