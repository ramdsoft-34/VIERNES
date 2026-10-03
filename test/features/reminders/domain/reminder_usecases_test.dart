import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/core/error/failure.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/create_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/delete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/reopen_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/snooze_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/update_reminder.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/fake_reminder_repository.dart';

void main() {
  late FakeReminderRepository repository;
  late FixedClock clock;

  setUp(() {
    repository = FakeReminderRepository();
    clock = FixedClock(DateTime(2026, 10, 1, 10));
  });

  group('CreateReminder', () {
    late CreateReminder create;
    setUp(() => create = CreateReminder(repository, clock, SequentialIds()));

    test(
      'guarda el recordatorio, limpia espacios y registra el evento',
      () async {
        final result = await create(
          ReminderDraft(
            title: '  Entregar el informe  ',
            notes: '   ',
            dueAt: DateTime(2026, 10, 2, 8),
            leadTime: const Duration(minutes: 30),
          ),
        );

        final reminder = result.valueOrNull!;
        expect(reminder.title, 'Entregar el informe');
        expect(reminder.notes, isNull);
        expect(reminder.remindAt, DateTime(2026, 10, 2, 7, 30));
        expect(repository.reminders, contains(reminder.id));
        expect(repository.events.single.type, ReminderEventType.created);
      },
    );

    test('rechaza un título vacío', () async {
      final result = await create(
        ReminderDraft(title: '  ', dueAt: DateTime(2026, 10, 2)),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repository.reminders, isEmpty);
    });

    test('rechaza una fecha pasada', () async {
      final result = await create(
        ReminderDraft(title: 'Tarde', dueAt: DateTime(2026, 9, 30)),
      );
      expect(
        (result.failureOrNull! as ValidationFailure).field,
        'dueAt',
      );
    });

    test('acepta "ahora mismo" dentro del margen de tolerancia', () async {
      final result = await create(
        ReminderDraft(
          title: 'Ya',
          dueAt: clock.now().subtract(const Duration(seconds: 30)),
        ),
      );
      expect(result.isOk, isTrue);
    });
  });

  group('CompleteReminder', () {
    late CompleteReminder complete;
    setUp(() => complete = CompleteReminder(repository, clock));

    test('un recordatorio único queda completado y a tiempo', () async {
      await repository.save(buildReminder(dueAt: DateTime(2026, 10, 1, 12)));

      final result = await complete('r1');

      final reminder = result.valueOrNull!;
      expect(reminder.status, ReminderStatus.completed);
      expect(reminder.completedAt, clock.now());
      expect(repository.events.last.type, ReminderEventType.completed);
      expect(repository.events.last.onTime, isTrue);
    });

    test('marca "tarde" si se confirma después de la hora límite', () async {
      await repository.save(buildReminder(dueAt: DateTime(2026, 10, 1, 8)));
      await complete('r1');
      expect(repository.events.last.onTime, isFalse);
    });

    test('uno que se repite avanza a la siguiente ocurrencia futura', () async {
      // Diario a las 8:00, vencido desde hace dos días.
      await repository.save(
        buildReminder(
          dueAt: DateTime(2026, 9, 29, 8),
          recurrence: Recurrence.daily,
          status: ReminderStatus.snoozed,
          snoozedUntil: DateTime(2026, 9, 29, 9),
        ),
      );

      final reminder = (await complete('r1')).valueOrNull!;

      expect(reminder.status, ReminderStatus.pending);
      expect(reminder.dueAt, DateTime(2026, 10, 2, 8));
      expect(reminder.snoozedUntil, isNull);
      expect(reminder.snoozeCount, 0);
    });

    test('no completa dos veces', () async {
      await repository.save(
        buildReminder(status: ReminderStatus.completed),
      );
      expect((await complete('r1')).failureOrNull, isA<ValidationFailure>());
    });

    test('deshacer restaura el estado y quita el evento', () async {
      final original = buildReminder();
      await repository.save(original);
      await complete('r1');

      await complete.undo(original);

      expect(repository.reminders['r1'], original);
      expect(
        repository.events.where((e) => e.type == ReminderEventType.completed),
        isEmpty,
      );
    });

    test('falla si no existe', () async {
      expect((await complete('nope')).failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('SnoozeReminder', () {
    late SnoozeReminder snooze;
    setUp(() => snooze = SnoozeReminder(repository, clock));

    test('pospone y cuenta los aplazamientos', () async {
      await repository.save(buildReminder());

      await snooze('r1', const Duration(minutes: 10));
      final reminder = (await snooze(
        'r1',
        const Duration(minutes: 10),
      )).valueOrNull!;

      expect(reminder.status, ReminderStatus.snoozed);
      expect(reminder.snoozedUntil, DateTime(2026, 10, 1, 10, 10));
      expect(reminder.nextTriggerAt, reminder.snoozedUntil);
      expect(reminder.snoozeCount, 2);
    });

    test('rechaza duraciones fuera de rango', () async {
      await repository.save(buildReminder());
      expect(
        (await snooze('r1', Duration.zero)).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await snooze('r1', const Duration(days: 8))).failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });

  group('UpdateReminder', () {
    late UpdateReminder update;
    setUp(() => update = UpdateReminder(repository, clock));

    test('cambiar la hora anula el aplazamiento', () async {
      final snoozed = buildReminder(
        status: ReminderStatus.snoozed,
        snoozedUntil: DateTime(2026, 10, 1, 11),
      );
      await repository.save(snoozed);

      final updated = (await update(
        snoozed.copyWith(dueAt: DateTime(2026, 10, 3, 9)),
      )).valueOrNull!;

      expect(updated.status, ReminderStatus.pending);
      expect(updated.snoozedUntil, isNull);
      expect(updated.updatedAt, clock.now());
    });

    test('editar solo el texto de algo vencido no exige fecha nueva', () async {
      final overdue = buildReminder(dueAt: DateTime(2026, 9, 1, 8));
      await repository.save(overdue);

      final result = await update(overdue.copyWith(title: 'Nuevo texto'));

      expect(result.valueOrNull?.title, 'Nuevo texto');
    });
  });

  group('Reopen, Delete y Restore', () {
    test('reabrir devuelve a pendiente', () async {
      await repository.save(
        buildReminder(status: ReminderStatus.completed),
      );
      final result = await ReopenReminder(repository, clock)('r1');
      expect(result.valueOrNull?.status, ReminderStatus.pending);
      expect(result.valueOrNull?.completedAt, isNull);
    });

    test('eliminar y restaurar conserva el recordatorio', () async {
      final original = buildReminder();
      await repository.save(original);

      final deleted = await DeleteReminder(repository, clock)('r1');
      expect(repository.reminders, isEmpty);

      await RestoreReminder(repository, clock)(deleted.valueOrNull!);
      expect(repository.reminders['r1'], original);
      expect(
        repository.events.map((e) => e.type),
        containsAllInOrder([
          ReminderEventType.deleted,
          ReminderEventType.restored,
        ]),
      );
    });
  });
}
