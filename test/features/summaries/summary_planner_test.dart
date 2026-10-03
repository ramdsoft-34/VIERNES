import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/alerts/domain/notification_ids.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/summaries/domain/summary_planner.dart';

import '../../helpers/builders.dart';

void main() {
  // Jueves 1 de octubre de 2026, 6:00 a. m. (antes del resumen de las 7).
  final now = DateTime(2026, 10, 1, 6);
  const settings = AppSettings();

  List<PlannedSummary> plan(List<dynamic> reminders, {DateTime? at}) =>
      SummaryPlanner.plan(
        active: reminders.cast(),
        settings: settings,
        now: at ?? now,
      );

  test('resumen de la mañana con lo de hoy, en orden', () {
    final plans = plan([
      buildReminder(
        id: 'b',
        title: 'Reunión',
        dueAt: DateTime(2026, 10, 1, 14),
      ),
      buildReminder(
        id: 'a',
        dueAt: DateTime(2026, 10, 1, 8),
      ),
    ]);

    final morning = plans.firstWhere((p) => p.kind == SummaryKind.morning);
    expect(morning.at, DateTime(2026, 10, 1, 7));
    expect(morning.title, 'Buenos días ☀️');
    expect(
      morning.body,
      'Hoy tienes 2 pendientes: entregar el informe a las 8 de la mañana y '
      'reunión a las 2 de la tarde.',
    );
    expect(morning.count, 2);
  });

  test('resumen de la noche con lo que vence antes de las 9 p. m.', () {
    final plans = plan([
      buildReminder(
        id: 'a',
        title: 'Llamar a Juan',
        dueAt: DateTime(2026, 10, 1, 10),
      ),
      buildReminder(
        id: 'b',
        title: 'Ver la serie',
        dueAt: DateTime(2026, 10, 1, 22),
      ),
    ]);

    final night = plans.firstWhere(
      (p) => p.kind == SummaryKind.night && p.at.day == 1,
    );
    expect(night.at, DateTime(2026, 10, 1, 21));
    expect(
      night.body,
      'Quedó 1 sin confirmar: llamar a Juan. ¿La paso a mañana?',
    );
    expect(night.payload, 'summary:night');
  });

  test('la noche de hoy incluye lo vencido de días anteriores', () {
    final plans = plan([
      buildReminder(title: 'Pagar la luz', dueAt: DateTime(2026, 9, 28, 9)),
    ]);
    final night = plans.firstWhere((p) => p.kind == SummaryKind.night);
    expect(night.body, contains('pagar la luz'));
  });

  test('días sin nada no generan resumen', () {
    final plans = plan([
      buildReminder(dueAt: DateTime(2026, 10, 3, 9)),
    ]);
    expect(plans.map((p) => p.at.day).toSet(), {3});
  });

  test('las repeticiones aparecen cada día', () {
    final plans = plan([
      buildReminder(
        title: 'Tomar la pastilla',
        dueAt: DateTime(2026, 10, 1, 9),
        recurrence: Recurrence.daily,
      ),
    ]);
    final mornings = plans.where((p) => p.kind == SummaryKind.morning);
    expect(mornings, hasLength(SummaryPlanner.days));
  });

  test('no programa resúmenes que ya pasaron', () {
    final plans = plan([
      buildReminder(dueAt: DateTime(2026, 10, 1, 15)),
    ], at: DateTime(2026, 10, 1, 8));
    expect(
      plans.where((p) => p.kind == SummaryKind.morning && p.at.day == 1),
      isEmpty,
    );
  });

  test('respeta los ajustes desactivados', () {
    final plans = SummaryPlanner.plan(
      active: [buildReminder(dueAt: DateTime(2026, 10, 1, 15))],
      settings: const AppSettings(
        morningSummaryEnabled: false,
        nightSummaryEnabled: false,
      ),
      now: now,
    );
    expect(plans, isEmpty);
  });

  test('los completados no cuentan', () {
    expect(
      plan([
        buildReminder(
          dueAt: DateTime(2026, 10, 1, 15),
          status: ReminderStatus.completed,
        ),
      ]),
      isEmpty,
    );
  });

  test('ids en el rango reservado y sin repetirse', () {
    final ids = SummaryPlanner.allIds;
    expect(ids.toSet(), hasLength(SummaryPlanner.days * 2));
    expect(ids.every((id) => id >= NotificationIds.reservedBase), isTrue);
  });
}
