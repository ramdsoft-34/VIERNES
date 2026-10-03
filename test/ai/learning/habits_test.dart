import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/learning/routine_suggester.dart';
import 'package:viernes/ai/learning/snooze_habits.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

import '../../helpers/builders.dart';

void main() {
  group('SnoozeHabits', () {
    late SnoozeHabits habits;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      habits = SnoozeHabits(await SharedPreferences.getInstance());
    });

    test('sin costumbre usa el tiempo de Ajustes', () async {
      await habits.record(const Duration(minutes: 10));
      expect(habits.learned(), isNull);
      expect(
        habits.preferred(const Duration(minutes: 5)),
        const Duration(minutes: 5),
      );
    });

    test('aprende el tiempo que más se elige', () async {
      for (final m in [10, 10, 30, 10]) {
        await habits.record(Duration(minutes: m));
      }
      expect(habits.learned(), const Duration(minutes: 10));
      expect(
        habits.preferred(const Duration(minutes: 5)),
        const Duration(minutes: 10),
      );
      // Con el aprendizaje apagado manda el ajuste.
      expect(
        habits.preferred(const Duration(minutes: 5), enabled: false),
        const Duration(minutes: 5),
      );
    });

    test('sin una mayoría clara no adivina', () async {
      for (final m in [5, 10, 30, 60]) {
        await habits.record(Duration(minutes: m));
      }
      expect(habits.learned(), isNull);
    });

    test('ignora «mañana» y solo recuerda las últimas elecciones', () async {
      await habits.record(const Duration(days: 1));
      expect(habits.choices(), isEmpty);
      for (var i = 0; i < SnoozeHabits.window + 5; i++) {
        await habits.record(const Duration(minutes: 15));
      }
      expect(habits.choices(), hasLength(SnoozeHabits.window));
    });

    test('ordena las opciones por uso', () async {
      for (final m in [30, 30, 5]) {
        await habits.record(Duration(minutes: m));
      }
      expect(
        habits.ordered(const [
          Duration(minutes: 5),
          Duration(minutes: 10),
          Duration(minutes: 30),
        ]),
        const [
          Duration(minutes: 30),
          Duration(minutes: 5),
          Duration(minutes: 10),
        ],
      );
    });
  });

  group('RoutineSuggester', () {
    final now = DateTime(2026, 10, 3, 10);

    test('nota algo que se crea cada mes y propone repetirlo', () {
      final reminders = [
        for (final (i, d) in [
          DateTime(2026, 7, 5, 9),
          DateTime(2026, 8, 5, 9),
          DateTime(2026, 9, 6, 9, 10),
        ].indexed)
          buildReminder(
            id: 'r$i',
            title: i == 0 ? 'Pagar la luz.' : 'pagar la luz',
            dueAt: d,
            status: ReminderStatus.completed,
          ),
      ];

      final suggestion = RoutineSuggester.suggest(reminders, now: now).single;

      expect(suggestion.recurrence.frequency, RecurrenceFrequency.monthly);
      expect(suggestion.recurrence.monthDay, 5);
      expect(suggestion.time, const DayTime(9, 0));
      expect(suggestion.occurrences, 3);
      expect(suggestion.activeReminderId, isNull);
      expect(suggestion.nextDue(now), DateTime(2026, 10, 5, 9));
    });

    test('cada semana el mismo día', () {
      final reminders = [
        for (final (i, d) in [
          DateTime(2026, 9, 12, 8),
          DateTime(2026, 9, 19, 8),
          DateTime(2026, 9, 26, 8),
          DateTime(2026, 10, 3, 8),
        ].indexed)
          buildReminder(
            id: 'w$i',
            title: 'Sacar la basura',
            dueAt: d,
            status: i == 3 ? ReminderStatus.pending : ReminderStatus.completed,
          ),
      ];

      final suggestion = RoutineSuggester.suggest(reminders, now: now).single;

      expect(suggestion.recurrence.frequency, RecurrenceFrequency.weekly);
      expect(suggestion.recurrence.weekdays, {DateTime.saturday});
      // Ya hay uno pendiente: se convierte en vez de crear otro.
      expect(suggestion.activeReminderId, 'w3');
    });

    test('no propone lo irregular, lo descartado ni lo que ya se repite', () {
      final irregular = [
        for (final (i, d) in [
          DateTime(2026, 9),
          DateTime(2026, 9, 3),
          DateTime(2026, 9, 20),
        ].indexed)
          buildReminder(id: 'i$i', title: 'Llamar a Juan', dueAt: d),
      ];
      final monthly = [
        for (final (i, d) in [
          DateTime(2026, 7, 5),
          DateTime(2026, 8, 5),
          DateTime(2026, 9, 5),
        ].indexed)
          buildReminder(id: 'm$i', title: 'Pagar el agua', dueAt: d),
      ];

      expect(RoutineSuggester.suggest(irregular, now: now), isEmpty);
      expect(
        RoutineSuggester.suggest(
          monthly,
          now: now,
          dismissed: {RoutineSuggester.keyOf('Pagar el agua')},
        ),
        isEmpty,
      );
      expect(
        RoutineSuggester.suggest([
          ...monthly,
          buildReminder(
            id: 'rep',
            title: 'Pagar el agua',
            recurrence: Recurrence.monthly(5),
          ),
        ], now: now),
        isEmpty,
      );
    });

    test('una costumbre vieja ya no cuenta', () {
      final old = [
        for (final (i, d) in [
          DateTime(2026, 1, 5),
          DateTime(2026, 2, 5),
          DateTime(2026, 3, 5),
        ].indexed)
          buildReminder(id: 'o$i', title: 'Renovar', dueAt: d),
      ];
      expect(RoutineSuggester.suggest(old, now: now), isEmpty);
    });
  });
}
