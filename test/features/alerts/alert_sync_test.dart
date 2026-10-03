import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/alerts/application/alert_action_handler.dart';
import 'package:viernes/features/alerts/application/reminder_alert_sync.dart';
import 'package:viernes/features/alerts/application/scheduling_reminder_repository.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/create_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/delete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/snooze_reminder.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_alert_scheduler.dart';
import '../../helpers/fake_reminder_repository.dart';

void main() {
  final now = DateTime(2026, 10, 1, 10);
  late FakeAlertScheduler scheduler;
  late FixedClock clock;
  late ReminderAlertSync sync;
  late SchedulingReminderRepository repository;
  var settings = const AppSettings();

  setUpAll(() => initializeDateFormatting('es'));

  setUp(() {
    settings = const AppSettings();
    scheduler = FakeAlertScheduler();
    clock = FixedClock(now);
    sync = ReminderAlertSync(
      scheduler: scheduler,
      settings: () => settings,
      clock: clock,
      l10n: lookupAppLocalizations(const Locale('es')),
    );
    repository = SchedulingReminderRepository(FakeReminderRepository(), sync);
  });

  test('crear un recordatorio programa sus avisos', () async {
    final reminder = (await CreateReminder(repository, clock, SequentialIds())(
      ReminderDraft(
        title: 'Entregar el informe',
        dueAt: DateTime(2026, 10, 2, 8),
        leadTime: const Duration(minutes: 30),
      ),
    )).valueOrNull!;

    final alerts = scheduler.alertsFor(reminder.id);
    expect(alerts.first.at, DateTime(2026, 10, 2, 7, 30));
    expect(alerts, hasLength(4));

    final content = scheduler.scheduled[alerts.first.notificationId]!.$2;
    expect(content.title, 'Entregar el informe');
    // El texto se calcula para el momento en que suena: a las 7:30 de
    // mañana, la entrega es "hoy".
    expect(content.body, startsWith('Hoy · 8:00'));
    expect(content.body, contains('faltan 30 min'));
  });

  test('completar cancela todos los avisos', () async {
    await repository.save(buildReminder(dueAt: DateTime(2026, 10, 1, 15)));
    expect(scheduler.alertsFor('r1'), isNotEmpty);

    await CompleteReminder(repository, clock)('r1');

    expect(scheduler.alertsFor('r1'), isEmpty);
  });

  test('un recordatorio diario completado se programa para mañana', () async {
    await repository.save(
      buildReminder(
        dueAt: DateTime(2026, 10, 1, 9),
        recurrence: Recurrence.daily,
      ),
    );

    await CompleteReminder(repository, clock)('r1');

    expect(scheduler.alertsFor('r1').first.at, DateTime(2026, 10, 2, 9));
  });

  test('posponer reprograma al terminar el aplazamiento', () async {
    await repository.save(buildReminder(dueAt: DateTime(2026, 10, 1, 9, 55)));

    await SnoozeReminder(repository, clock)('r1', const Duration(minutes: 10));

    final alerts = scheduler.alertsFor('r1');
    expect(alerts.first.at, DateTime(2026, 10, 1, 10, 10));
    expect(alerts.first.step, 0);
  });

  test('eliminar quita los avisos', () async {
    await repository.save(buildReminder(dueAt: DateTime(2026, 10, 1, 15)));
    await DeleteReminder(repository, clock)('r1');
    expect(scheduler.scheduled, isEmpty);
  });

  test('syncAll reprograma solo los activos', () async {
    await sync.syncAll([
      buildReminder(id: 'a', dueAt: DateTime(2026, 10, 1, 15)),
      buildReminder(id: 'b', status: ReminderStatus.completed),
    ]);
    expect(scheduler.alertsFor('a'), isNotEmpty);
    expect(scheduler.alertsFor('b'), isEmpty);
  });

  test('las insistencias dicen que sigue pendiente', () async {
    await repository.save(buildReminder(dueAt: DateTime(2026, 10, 1, 15)));
    final escalation = scheduler.alertsFor('r1')[1];
    expect(
      scheduler.scheduled[escalation.notificationId]!.$2.body,
      startsWith('Sigue pendiente'),
    );
  });

  group('AlertActionHandler', () {
    late AlertActionHandler handler;
    setUp(() {
      handler = AlertActionHandler(
        complete: CompleteReminder(repository, clock),
        snooze: SnoozeReminder(repository, clock),
        snoozeDuration: () => const Duration(minutes: 15),
      );
    });

    test('"Ya lo hice" completa', () async {
      await repository.save(buildReminder());
      final updated = await handler.handle(
        actionId: AlertActions.complete,
        reminderId: 'r1',
      );
      expect(updated!.status, ReminderStatus.completed);
    });

    test('"Recordar después" usa el tiempo de los ajustes', () async {
      await repository.save(buildReminder());
      final updated = await handler.handle(
        actionId: AlertActions.snooze,
        reminderId: 'r1',
      );
      expect(updated!.snoozedUntil, DateTime(2026, 10, 1, 10, 15));
    });

    test('acciones desconocidas o sin recordatorio no hacen nada', () async {
      expect(await handler.handle(actionId: 'x', reminderId: 'r1'), isNull);
      expect(
        await handler.handle(actionId: AlertActions.complete, reminderId: null),
        isNull,
      );
    });
  });
}
