import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Costumbres aprendidas de los recordatorios del usuario.
///
/// Ejemplo: si casi todo lo que agenda "en la tarde" queda a las 4:00 p. m.,
/// Viernes deja de suponer las 3:00 p. m. por defecto.
@immutable
class PersonalHabits {
  const PersonalHabits({
    this.periodTimes = const {},
    this.leadTimes = const {},
  });

  factory PersonalHabits.learn(Iterable<Reminder> reminders) {
    final byPeriod = <DayPeriod, List<int>>{};
    final leadsByCategory = <ReminderCategory, List<Duration>>{};

    for (final reminder in reminders) {
      final minutes = reminder.dueAt.hour * 60 + reminder.dueAt.minute;
      final period = _periodOf(reminder.dueAt.hour);
      if (period != null) (byPeriod[period] ??= []).add(minutes);
      (leadsByCategory[reminder.category] ??= []).add(reminder.leadTime);
    }

    return PersonalHabits(
      periodTimes: {
        for (final MapEntry(key: period, value: values) in byPeriod.entries)
          if (values.length >= minSamples) period: _median(values),
      },
      leadTimes: {
        for (final MapEntry(key: category, value: leads)
            in leadsByCategory.entries)
          category: ?_mode(leads),
      },
    );
  }

  /// Mínimo de ejemplos para confiar en una costumbre.
  static const minSamples = 3;

  /// Hora habitual por franja (mañana, tarde, noche).
  final Map<DayPeriod, DayTime> periodTimes;

  /// Anticipación habitual por categoría.
  final Map<ReminderCategory, Duration> leadTimes;

  bool get isEmpty => periodTimes.isEmpty && leadTimes.isEmpty;

  /// Franja a la que pertenece una hora. El mediodía y la madrugada se dejan
  /// fijos: casi siempre significan lo mismo para todos.
  static DayPeriod? _periodOf(int hour) => switch (hour) {
    >= 6 && < 12 => DayPeriod.morning,
    >= 13 && < 19 => DayPeriod.afternoon,
    >= 19 && < 24 => DayPeriod.night,
    _ => null,
  };

  /// Mediana redondeada al cuarto de hora más cercano.
  static DayTime _median(List<int> minutes) {
    final sorted = [...minutes]..sort();
    final middle = sorted[sorted.length ~/ 2];
    final rounded = ((middle / 15).round() * 15).clamp(0, 23 * 60 + 45);
    return DayTime.fromMinutes(rounded);
  }

  /// La anticipación más usada, solo si es clara (al menos la mitad).
  static Duration? _mode(List<Duration> leads) {
    if (leads.length < minSamples) return null;
    final counts = <Duration, int>{};
    for (final lead in leads) {
      counts.update(lead, (c) => c + 1, ifAbsent: () => 1);
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return top.value * 2 >= leads.length ? top.key : null;
  }
}
