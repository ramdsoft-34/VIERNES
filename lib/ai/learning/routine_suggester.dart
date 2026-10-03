import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Viernes notó que el usuario crea la misma tarea con regularidad y propone
/// dejarla repetitiva: «Creas "Pagar la luz" cada mes. ¿Lo dejo así?».
@immutable
class RoutineSuggestion {
  const RoutineSuggestion({
    required this.key,
    required this.title,
    required this.recurrence,
    required this.time,
    required this.occurrences,
    required this.lastDue,
    this.activeReminderId,
  });

  /// Título normalizado: identifica la costumbre (para descartarla).
  final String key;

  /// Título tal como lo escribió el usuario la última vez.
  final String title;
  final Recurrence recurrence;

  /// Hora habitual.
  final DayTime time;

  /// Cuántas veces se vio.
  final int occurrences;
  final DateTime lastDue;

  /// Si hay uno pendiente con ese título, se convierte en repetitivo en vez
  /// de crear otro.
  final String? activeReminderId;

  /// Próxima fecha de la rutina después de [now].
  DateTime nextDue(DateTime now) {
    var next = lastDue.startOfDay.withTime(time.hour, time.minute);
    var guard = 0;
    while (!next.isAfter(now) && guard++ < 800) {
      next = recurrence.nextAfter(next) ?? now.addDays(1);
    }
    return next;
  }

  @override
  String toString() => 'RoutineSuggestion($title, ${recurrence.encode()})';
}

/// Busca costumbres en los recordatorios que no se repiten.
abstract final class RoutineSuggester {
  /// Mínimo de veces para proponer una rutina.
  static const minOccurrences = 3;

  /// Clave con la que se agrupan títulos parecidos («Pagar la luz.» y
  /// «pagar la luz» son lo mismo).
  static String keyOf(String title) =>
      SpanishText.fold(
            title,
          )
          .replaceAll(RegExp('[^a-z0-9ñ ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  static List<RoutineSuggestion> suggest(
    Iterable<Reminder> reminders, {
    required DateTime now,
    Set<String> dismissed = const {},
  }) {
    final groups = <String, List<Reminder>>{};
    final alreadyRepeating = <String>{};
    for (final reminder in reminders) {
      final key = keyOf(reminder.title);
      if (key.isEmpty) continue;
      if (reminder.recurrence.repeats) {
        if (reminder.isActive) alreadyRepeating.add(key);
        continue;
      }
      (groups[key] ??= []).add(reminder);
    }

    final suggestions = <RoutineSuggestion>[];
    for (final MapEntry(:key, value: items) in groups.entries) {
      if (dismissed.contains(key) || alreadyRepeating.contains(key)) continue;
      // Una por día: dos recordatorios el mismo día no son una rutina.
      final byDay = <DateTime, Reminder>{};
      for (final r in items) {
        byDay.putIfAbsent(r.dueAt.startOfDay, () => r);
      }
      final ordered = byDay.values.toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      if (ordered.length < minOccurrences) continue;

      final recurrence = _detect(ordered);
      if (recurrence == null) continue;

      // Que siga vigente: la última vez no fue hace demasiado.
      final last = ordered.last.dueAt;
      if (now.difference(last) > _staleAfter(recurrence)) continue;

      final active =
          items.where((r) => r.status != ReminderStatus.completed).toList()
            ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
      suggestions.add(
        RoutineSuggestion(
          key: key,
          title: ordered.last.title,
          recurrence: recurrence,
          time: _usualTime(ordered),
          occurrences: ordered.length,
          lastDue: last,
          activeReminderId: active.firstOrNull?.id,
        ),
      );
    }
    suggestions.sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return suggestions;
  }

  static Recurrence? _detect(List<Reminder> ordered) {
    final gaps = [
      for (var i = 1; i < ordered.length; i++)
        ordered[i].dueAt.startOfDay
                .difference(ordered[i - 1].dueAt.startOfDay)
                .inHours /
            24,
    ].map((g) => g.round()).toList();

    // Todos los días (al menos 4 seguidos para no confundir con casualidad).
    if (ordered.length >= 4 && gaps.every((g) => g == 1)) {
      return Recurrence.daily;
    }
    // De lunes a viernes: saltos de 1 día y de 3 (viernes → lunes).
    if (ordered.length >= 4 &&
        ordered.every((r) => r.dueAt.weekday <= DateTime.friday) &&
        gaps.every((g) => g == 1 || g == 3) &&
        gaps.contains(3)) {
      return Recurrence.weekdaysOnly;
    }
    // Cada semana, el mismo día.
    if (gaps.every((g) => g >= 6 && g <= 8)) {
      final weekday = _mostCommon([for (final r in ordered) r.dueAt.weekday]);
      final same = ordered.where((r) => r.dueAt.weekday == weekday).length;
      if (same * 3 >= ordered.length * 2) return Recurrence.weekly({weekday});
    }
    // Cada mes, más o menos el mismo día.
    if (gaps.every((g) => g >= 26 && g <= 35)) {
      final days = [for (final r in ordered) r.dueAt.day]..sort();
      if (days.last - days.first <= 3) {
        return Recurrence.monthly(days[days.length ~/ 2]);
      }
    }
    return null;
  }

  /// Después de dos periodos sin verla, la costumbre ya no cuenta.
  static Duration _staleAfter(Recurrence r) => switch (r.frequency) {
    RecurrenceFrequency.daily || RecurrenceFrequency.weekdays => const Duration(
      days: 5,
    ),
    RecurrenceFrequency.weekly => const Duration(days: 15),
    _ => const Duration(days: 65),
  };

  /// Mediana de las horas, redondeada al cuarto de hora.
  static DayTime _usualTime(List<Reminder> ordered) {
    final minutes = [
      for (final r in ordered) r.dueAt.hour * 60 + r.dueAt.minute,
    ]..sort();
    final middle = minutes[minutes.length ~/ 2];
    return DayTime.fromMinutes(
      ((middle / 15).round() * 15).clamp(0, 23 * 60 + 45),
    );
  }

  static int _mostCommon(List<int> values) {
    final counts = <int, int>{};
    for (final v in values) {
      counts.update(v, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
