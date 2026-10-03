import 'package:flutter/foundation.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';

/// Un recordatorio ubicado en una fecha concreta del calendario.
@immutable
class Occurrence {
  const Occurrence(this.reminder, this.at);

  final Reminder reminder;
  final DateTime at;

  /// `true` si es una repetición futura y no la ocurrencia actual guardada.
  bool get isProjected => at != reminder.dueAt;
}

abstract final class CalendarOccurrences {
  /// Límite de seguridad por recordatorio (p. ej. diarios en un rango largo).
  static const maxPerReminder = 400;

  /// Agrupa por día las ocurrencias dentro de `[from, to)`. Los recordatorios
  /// activos que se repiten se proyectan hacia adelante.
  static Map<DateTime, List<Occurrence>> expand(
    Iterable<Reminder> reminders,
    DateTime from,
    DateTime to,
  ) {
    final byDay = <DateTime, List<Occurrence>>{};
    void add(Reminder reminder, DateTime at) {
      if (at.isBefore(from) || !at.isBefore(to)) return;
      (byDay[at.startOfDay] ??= []).add(Occurrence(reminder, at));
    }

    for (final reminder in reminders) {
      add(reminder, reminder.dueAt);
      if (!reminder.isActive || !reminder.recurrence.repeats) continue;
      var next = reminder.recurrence.nextAfter(reminder.dueAt);
      var count = 0;
      while (next != null && next.isBefore(to) && count < maxPerReminder) {
        add(reminder, next);
        next = reminder.recurrence.nextAfter(next);
        count++;
      }
    }

    for (final list in byDay.values) {
      list.sort((a, b) => a.at.compareTo(b.at));
    }
    return byDay;
  }
}
