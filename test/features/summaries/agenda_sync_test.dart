import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:viernes/core/utils/clock.dart';
import 'package:viernes/features/alerts/application/alert_action_handler.dart';
import 'package:viernes/features/alerts/application/reminder_alert_sync.dart';
import 'package:viernes/features/alerts/application/scheduling_reminder_repository.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/usecases/complete_reminder.dart';
import 'package:viernes/features/reminders/domain/usecases/move_overdue_to_tomorrow.dart';
import 'package:viernes/features/reminders/domain/usecases/snooze_reminder.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/summaries/application/agenda_sync.dart';
import 'package:viernes/features/summaries/domain/summary_planner.dart';
import 'package:viernes/l10n/gen/app_localizations.dart';

import '../../helpers/builders.dart';
import '../../helpers/fake_alert_scheduler.dart';
import '../../helpers/fake_reminder_repository.dart';

class _FakeSummaries implements SummaryScheduler {
  List<PlannedSummary> current = [];
  int calls = 0;

  @override
  Future<void> replaceSummaries(List<PlannedSummary> summaries) async {
    calls++;
    current = summaries;
  }
}

class _FakeWidget implements HomeWidgetUpdater {
  List<WidgetItem> items = [];

  @override
  Future<void> update(List<WidgetItem> items) async => this.items = items;
}

void main() {
  // Jueves 1 de octubre de 2026, 3:00 p. m.
  final now = DateTime(2026, 10, 1, 15);
  late FakeReminderRepository local;
  late _FakeSummaries summaries;
  late _FakeWidget widget;
  late AgendaSync agenda;
  late SchedulingReminderRepository repository;
  late FixedClock clock;

  setUpAll(() => initializeDateFormatting('es'));

  setUp(() {
    clock = FixedClock(now);
    local = FakeReminderRepository();
    summaries = _FakeSummaries();
    widget = _FakeWidget();
    agenda = AgendaSync(
      summaries: summaries,
      widget: widget,
      settings: () => const AppSettings(),
      clock: clock,
      loadActive: () => local.watchByStatus({
        ReminderStatus.pending,
        ReminderStatus.snoozed,
      }).first,
    );
    repository = SchedulingReminderRepository(
      local,
      ReminderAlertSync(
        scheduler: FakeAlertScheduler(),
        settings: () => const AppSettings(),
        clock: clock,
        l10n: lookupAppLocalizations(const Locale('es')),
      ),
      onChanged: agenda.refresh,
    );
  });

  test('cada cambio actualiza resúmenes y widget', () async {
    await repository.save(
      buildReminder(title: 'Llamar a Juan', dueAt: DateTime(2026, 10, 1, 18)),
    );

    expect(widget.items.single.title, 'Llamar a Juan');
    expect(
      summaries.current.where((s) => s.kind == SummaryKind.night),
      isNotEmpty,
    );

    await CompleteReminder(repository, clock)('r1');

    expect(widget.items, isEmpty);
    expect(summaries.current, isEmpty);
  });

  test('varios cambios seguidos se agrupan', () async {
    await Future.wait([agenda.refresh(), agenda.refresh(), agenda.refresh()]);
    expect(summaries.calls, lessThanOrEqualTo(2));
  });

  group('MoveOverdueToTomorrow', () {
    test('mueve los vencidos únicos a mañana a la misma hora', () async {
      await repository.save(
        buildReminder(id: 'a', dueAt: DateTime(2026, 10, 1, 9, 30)),
      );
      await repository.save(
        buildReminder(id: 'b', dueAt: DateTime(2026, 9, 29, 8)),
      );
      await repository.save(
        buildReminder(id: 'c', dueAt: DateTime(2026, 10, 1, 18)),
      );
      await repository.save(
        buildReminder(
          id: 'd',
          dueAt: DateTime(2026, 10, 1, 7),
          recurrence: Recurrence.daily,
        ),
      );

      final moved = await MoveOverdueToTomorrow(repository, clock)();

      expect(moved.valueOrNull, 2);
      expect(local.reminders['a']!.dueAt, DateTime(2026, 10, 2, 9, 30));
      expect(local.reminders['b']!.dueAt, DateTime(2026, 10, 2, 8));
      // Lo futuro y lo que se repite no se tocan.
      expect(local.reminders['c']!.dueAt, DateTime(2026, 10, 1, 18));
      expect(local.reminders['d']!.dueAt, DateTime(2026, 10, 1, 7));
    });

    test('quita el aplazamiento de los movidos', () async {
      await repository.save(
        buildReminder(
          dueAt: DateTime(2026, 10, 1, 9),
          status: ReminderStatus.snoozed,
          snoozedUntil: DateTime(2026, 10, 1, 9, 10),
        ),
      );
      await MoveOverdueToTomorrow(repository, clock)();
      final reminder = local.reminders['r1']!;
      expect(reminder.status, ReminderStatus.pending);
      expect(reminder.snoozedUntil, isNull);
    });

    test('"Pasar a mañana" desde el resumen de la noche', () async {
      await repository.save(buildReminder(dueAt: DateTime(2026, 10, 1, 9)));
      final handler = AlertActionHandler(
        complete: CompleteReminder(repository, clock),
        snooze: SnoozeReminder(repository, clock),
        snoozeDuration: () => const Duration(minutes: 10),
        moveOverdue: MoveOverdueToTomorrow(repository, clock),
      );

      expect(
        await handler.handleSummaryAction(AlertActions.moveToTomorrow),
        1,
      );
      expect(await handler.handleSummaryAction('otra'), isNull);
    });
  });

  test('si falla un paso, el otro sigue', () async {
    final failing = AgendaSync(
      summaries: _ThrowingSummaries(),
      widget: widget,
      settings: () => const AppSettings(),
      clock: clock,
      loadActive: () async => [buildReminder(dueAt: DateTime(2026, 10, 2))],
    );
    await failing.refresh();
    expect(widget.items, hasLength(1));
  });
}

class _ThrowingSummaries implements SummaryScheduler {
  @override
  Future<void> replaceSummaries(List<PlannedSummary> summaries) =>
      Future.error(StateError('sin notificaciones'));
}
