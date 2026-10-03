import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/core/database/app_database.dart';
import 'package:viernes/features/reminders/data/drift_reminder_repository.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

import '../../../helpers/builders.dart';

void main() {
  late AppDatabase db;
  late DriftReminderRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftReminderRepository(db);
  });

  tearDown(() => db.close());

  test('guarda y lee un recordatorio con todos sus campos', () async {
    final reminder = buildReminder(
      leadTime: const Duration(minutes: 45),
      recurrence: Recurrence.weekly(const {1, 4}),
      priority: ReminderPriority.urgent,
      status: ReminderStatus.snoozed,
      snoozedUntil: DateTime(2026, 10, 2, 7, 50),
    );

    await repository.save(reminder);

    expect(await repository.findById('r1'), reminder);
  });

  test('watchByStatus filtra y ordena por próximo aviso', () async {
    await repository.save(
      buildReminder(id: 'tarde', dueAt: DateTime(2026, 10, 5)),
    );
    await repository.save(
      buildReminder(id: 'pronto', dueAt: DateTime(2026, 10, 3)),
    );
    await repository.save(
      buildReminder(id: 'hecho', status: ReminderStatus.completed),
    );

    final pending = await repository.watchByStatus({
      ReminderStatus.pending,
    }).first;

    expect(pending.map((r) => r.id), ['pronto', 'tarde']);
  });

  test('guardar con evento lo registra en el historial', () async {
    final reminder = buildReminder();
    await repository.save(
      reminder,
      event: ReminderEvent(
        reminderId: reminder.id,
        reminderTitle: reminder.title,
        type: ReminderEventType.completed,
        occurredAt: DateTime(2026, 10, 1, 9),
        onTime: true,
      ),
    );

    final events = await repository.watchEvents().first;
    expect(events.single.type, ReminderEventType.completed);
    expect(events.single.onTime, isTrue);
  });

  test('el historial sobrevive a la eliminación', () async {
    final reminder = buildReminder();
    await repository.save(reminder);
    await repository.delete(
      reminder.id,
      event: ReminderEvent(
        reminderId: reminder.id,
        reminderTitle: reminder.title,
        type: ReminderEventType.deleted,
        occurredAt: DateTime(2026, 10, 1, 9),
      ),
    );

    expect(await repository.findById(reminder.id), isNull);
    expect(
      (await repository.watchEvents().first).single.reminderTitle,
      reminder.title,
    );
  });

  test('revert restaura y borra solo el último evento de ese tipo', () async {
    final original = buildReminder();
    ReminderEvent completed(int hour) => ReminderEvent(
      reminderId: original.id,
      reminderTitle: original.title,
      type: ReminderEventType.completed,
      occurredAt: DateTime(2026, 10, 1, hour),
    );
    await repository.save(original, event: completed(8));
    await repository.save(
      original.copyWith(status: ReminderStatus.completed),
      event: completed(9),
    );

    await repository.revert(
      original,
      undoneEvent: ReminderEventType.completed,
    );

    expect(await repository.findById(original.id), original);
    final events = await repository.watchEvents().first;
    expect(events.single.occurredAt, DateTime(2026, 10, 1, 8));
  });
}
