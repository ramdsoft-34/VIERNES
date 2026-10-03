import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/calendar/domain/calendar_occurrences.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

import '../../helpers/builders.dart';

void main() {
  final from = DateTime(2026, 10);
  final to = DateTime(2026, 11);

  test('ubica un recordatorio único en su día', () {
    final byDay = CalendarOccurrences.expand(
      [buildReminder(dueAt: DateTime(2026, 10, 20, 15))],
      from,
      to,
    );
    expect(byDay.keys, [DateTime(2026, 10, 20)]);
    expect(byDay.values.single.single.isProjected, isFalse);
  });

  test('proyecta las repeticiones semanales dentro del rango', () {
    final weekly = buildReminder(
      dueAt: DateTime(2026, 10, 5, 7), // lunes
      recurrence: Recurrence.weekly(const {DateTime.monday}),
    );
    final byDay = CalendarOccurrences.expand([weekly], from, to);
    expect(byDay.keys, [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 26),
    ]);
    expect(byDay[DateTime(2026, 10, 12)]!.single.isProjected, isTrue);
  });

  test('no proyecta repeticiones de recordatorios completados', () {
    final done = buildReminder(
      dueAt: DateTime(2026, 10, 5, 7),
      recurrence: Recurrence.daily,
      status: ReminderStatus.completed,
    );
    expect(CalendarOccurrences.expand([done], from, to).length, 1);
  });

  test('ordena por hora dentro del día', () {
    final byDay = CalendarOccurrences.expand(
      [
        buildReminder(id: 'b', dueAt: DateTime(2026, 10, 9, 18)),
        buildReminder(id: 'a', dueAt: DateTime(2026, 10, 9, 7)),
      ],
      from,
      to,
    );
    expect(byDay[DateTime(2026, 10, 9)]!.map((o) => o.reminder.id), [
      'a',
      'b',
    ]);
  });
}
