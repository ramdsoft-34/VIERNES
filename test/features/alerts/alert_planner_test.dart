import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/alerts/domain/alert_planner.dart';
import 'package:viernes/features/alerts/domain/notification_ids.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';

import '../../helpers/builders.dart';

void main() {
  final now = DateTime(2026, 10, 1, 10);
  const settings = AppSettings();

  group('AlertPlanner', () {
    test('aviso principal más tres insistencias', () {
      final reminder = buildReminder(
        dueAt: DateTime(2026, 10, 1, 15),
        leadTime: const Duration(minutes: 15),
      );

      final plan = AlertPlanner.plan(reminder, settings, now);

      expect(plan.map((a) => a.at), [
        DateTime(2026, 10, 1, 14, 45),
        DateTime(2026, 10, 1, 14, 55),
        DateTime(2026, 10, 1, 15, 15),
        DateTime(2026, 10, 1, 15, 45),
      ]);
      expect(plan.map((a) => a.step), [0, 1, 2, 3]);
      expect(plan.first.fullScreen, isTrue);
      // Solo la última insistencia suena hasta que se atienda.
      expect(plan.map((a) => a.insistent), [false, false, false, true]);
    });

    test('sin insistencia solo hay aviso principal', () {
      final plan = AlertPlanner.plan(
        buildReminder(dueAt: DateTime(2026, 10, 1, 15)),
        const AppSettings(escalationEnabled: false),
        now,
      );
      expect(plan, hasLength(1));
    });

    test('nada para recordatorios completados', () {
      expect(
        AlertPlanner.plan(
          buildReminder(status: ReminderStatus.completed),
          settings,
          now,
        ),
        isEmpty,
      );
    });

    test('pospuesto: avisa al terminar el aplazamiento', () {
      final plan = AlertPlanner.plan(
        buildReminder(
          dueAt: DateTime(2026, 10, 1, 9),
          status: ReminderStatus.snoozed,
          snoozedUntil: DateTime(2026, 10, 1, 10, 10),
        ),
        settings,
        now,
      );
      expect(plan.first.at, DateTime(2026, 10, 1, 10, 10));
    });

    test('si el aviso ya pasó, quedan las insistencias futuras', () {
      final plan = AlertPlanner.plan(
        buildReminder(dueAt: DateTime(2026, 10, 1, 9, 50)),
        settings,
        now,
      );
      expect(plan.map((a) => a.step), [2, 3]);
    });

    test('horario de silencio: aviso sin sonido y sin insistir', () {
      const quiet = AppSettings(quietHoursEnabled: true);
      final plan = AlertPlanner.plan(
        buildReminder(dueAt: DateTime(2026, 10, 1, 23)),
        quiet,
        now,
      );
      expect(plan, hasLength(1));
      expect(plan.single.silent, isTrue);
      expect(plan.single.fullScreen, isFalse);
    });

    test('lo urgente suena aunque sea horario de silencio', () {
      const quiet = AppSettings(quietHoursEnabled: true);
      final plan = AlertPlanner.plan(
        buildReminder(
          dueAt: DateTime(2026, 10, 1, 23),
          priority: ReminderPriority.urgent,
        ),
        quiet,
        now,
      );
      expect(plan, hasLength(4));
      expect(plan.every((a) => !a.silent && a.urgent && a.insistent), isTrue);
    });

    test('sin pantalla completa si el usuario la desactiva', () {
      final plan = AlertPlanner.plan(
        buildReminder(dueAt: DateTime(2026, 10, 1, 15)),
        const AppSettings(fullScreenAlerts: false),
        now,
      );
      expect(plan.any((a) => a.fullScreen), isFalse);
    });
  });

  group('NotificationIds', () {
    test('son estables y distintos por paso', () {
      final ids = NotificationIds.allFor('abc');
      expect(ids, NotificationIds.allFor('abc'));
      expect(ids.toSet(), hasLength(NotificationIds.slotsPerReminder));
      expect(
        NotificationIds.forReminder('abc', 0),
        isNot(
          NotificationIds.forReminder('abd', 0),
        ),
      );
    });

    test('caben en 32 bits sin tocar los ids reservados', () {
      for (final id in [
        'a',
        'zzzzzzzz',
        '0192f1c3-7d1e-7abc-9def-1234567890ab',
      ]) {
        for (final value in NotificationIds.allFor(id)) {
          expect(value, inInclusiveRange(0, NotificationIds.reservedBase - 1));
        }
      }
    });
  });
}
