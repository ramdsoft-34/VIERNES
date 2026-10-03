import 'package:flutter/foundation.dart';
import 'package:viernes/core/utils/date_x.dart';

enum RecurrenceFrequency { none, daily, weekdays, weekly, monthly, yearly }

/// Regla de repetición de un recordatorio.
///
/// Se serializa con un formato inspirado en RRULE (RFC 5545) para que, si en
/// el futuro se sincroniza con calendarios externos, la traducción sea directa:
/// `FREQ=WEEKLY;INTERVAL=1;BYDAY=1,3`.
@immutable
class Recurrence {
  const Recurrence({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const {},
    this.monthDay,
    this.until,
  }) : assert(interval >= 1, 'interval debe ser >= 1');

  factory Recurrence.weekly(Set<int> weekdays, {int interval = 1}) =>
      Recurrence(
        frequency: RecurrenceFrequency.weekly,
        interval: interval,
        weekdays: weekdays,
      );

  /// [monthDay] conserva el día original (p. ej. 31) aunque algún mes no
  /// lo tenga.
  factory Recurrence.monthly(int monthDay, {int interval = 1}) => Recurrence(
    frequency: RecurrenceFrequency.monthly,
    interval: interval,
    monthDay: monthDay,
  );

  factory Recurrence.yearly(int monthDay) => Recurrence(
    frequency: RecurrenceFrequency.yearly,
    monthDay: monthDay,
  );

  factory Recurrence.decode(String? raw) {
    if (raw == null || raw.isEmpty) return none;
    final parts = <String, String>{};
    for (final pair in raw.split(';')) {
      final index = pair.indexOf('=');
      if (index > 0) {
        parts[pair.substring(0, index)] = pair.substring(index + 1);
      }
    }
    final frequency = RecurrenceFrequency.values.firstWhere(
      (f) => f.name.toUpperCase() == parts['FREQ'],
      orElse: () => RecurrenceFrequency.none,
    );
    if (frequency == RecurrenceFrequency.none) return none;
    final byDay = parts['BYDAY'];
    final until = parts['UNTIL'];
    return Recurrence(
      until: until == null || until.length != 8
          ? null
          : DateTime.tryParse(until),
      frequency: frequency,
      interval: int.tryParse(parts['INTERVAL'] ?? '') ?? 1,
      weekdays: byDay == null || byDay.isEmpty
          ? const {}
          : byDay.split(',').map(int.tryParse).nonNulls.toSet(),
      monthDay: int.tryParse(parts['BYMONTHDAY'] ?? ''),
    );
  }

  static const none = Recurrence(frequency: RecurrenceFrequency.none);
  static const daily = Recurrence(frequency: RecurrenceFrequency.daily);
  static const weekdaysOnly = Recurrence(
    frequency: RecurrenceFrequency.weekdays,
  );

  final RecurrenceFrequency frequency;

  /// Cada cuántas unidades se repite (cada 2 semanas → 2).
  final int interval;

  /// Días de la semana para [RecurrenceFrequency.weekly]
  /// (`DateTime.monday` = 1 … `DateTime.sunday` = 7).
  final Set<int> weekdays;

  final int? monthDay;

  /// Último día (inclusive) en que se repite: «por 30 días», «del 5 al 10».
  /// Nulo si se repite sin fin. Solo cuenta la fecha, no la hora.
  final DateTime? until;

  bool get repeats => frequency != RecurrenceFrequency.none;

  String encode() {
    final buffer = StringBuffer('FREQ=${frequency.name.toUpperCase()}')
      ..write(';INTERVAL=$interval');
    if (weekdays.isNotEmpty) {
      buffer.write(';BYDAY=${(weekdays.toList()..sort()).join(',')}');
    }
    if (monthDay != null) buffer.write(';BYMONTHDAY=$monthDay');
    final last = until;
    if (last != null) {
      buffer.write(
        ';UNTIL=${last.year.toString().padLeft(4, '0')}'
        '${last.month.toString().padLeft(2, '0')}'
        '${last.day.toString().padLeft(2, '0')}',
      );
    }
    return buffer.toString();
  }

  /// La misma regla con otro último día (o sin fin si [until] es nulo).
  Recurrence withUntil(DateTime? until) => Recurrence(
    frequency: frequency,
    interval: interval,
    weekdays: weekdays,
    monthDay: monthDay,
    until: until?.startOfDay,
  );

  /// Siguiente ocurrencia estrictamente posterior a [current], o `null` si no
  /// se repite o ya pasó su último día ([until]). Conserva la hora de reloj.
  DateTime? nextAfter(DateTime current) {
    final next = _nextAfter(current);
    final last = until;
    if (next == null || last == null) return next;
    return next.startOfDay.isAfter(last.startOfDay) ? null : next;
  }

  DateTime? _nextAfter(DateTime current) {
    switch (frequency) {
      case RecurrenceFrequency.none:
        return null;
      case RecurrenceFrequency.daily:
        return current.addDays(interval);
      case RecurrenceFrequency.weekdays:
        var next = current.addDays(1);
        while (next.weekday > DateTime.friday) {
          next = next.addDays(1);
        }
        return next;
      case RecurrenceFrequency.weekly:
        if (weekdays.isEmpty) return current.addDays(7 * interval);
        for (var offset = 1; offset <= 7; offset++) {
          final candidate = current.addDays(offset);
          if (!weekdays.contains(candidate.weekday)) continue;
          final wrappedToNextWeek = candidate.weekday <= current.weekday;
          return wrappedToNextWeek && interval > 1
              ? candidate.addDays(7 * (interval - 1))
              : candidate;
        }
        return current.addDays(7 * interval);
      case RecurrenceFrequency.monthly:
        return current.addMonthsClamped(interval, anchorDay: monthDay);
      case RecurrenceFrequency.yearly:
        return current.addMonthsClamped(12 * interval, anchorDay: monthDay);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;

  @override
  String toString() => 'Recurrence(${encode()})';
}
