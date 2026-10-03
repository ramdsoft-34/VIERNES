import 'package:flutter/foundation.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_event.dart';

/// Indicadores de progreso calculados a partir de los eventos.
@immutable
class HistoryStats {
  const HistoryStats({
    required this.totalCompleted,
    required this.completedThisWeek,
    required this.currentStreak,
    required this.bestStreak,
    required this.onTimeRate,
    required this.snoozedLast30Days,
    this.dailyCompletions = const [0, 0, 0, 0, 0, 0, 0],
    this.mostSnoozed = const [],
  });

  factory HistoryStats.from(Iterable<ReminderEvent> events, DateTime now) {
    final completions = events
        .where((e) => e.type == ReminderEventType.completed)
        .toList();
    final days = completions.map((e) => e.occurredAt.startOfDay).toSet();
    final rated = completions.where((e) => e.onTime != null).toList();
    final monthAgo = now.subtract(const Duration(days: 30));
    final today = now.startOfDay;

    // Completados por día: [hace 6 días, …, hoy].
    final daily = List.filled(chartDays, 0);
    for (final event in completions) {
      final ago = today.difference(event.occurredAt.startOfDay).inDays;
      if (ago >= 0 && ago < chartDays) daily[chartDays - 1 - ago]++;
    }

    // Títulos pospuestos más veces en los últimos 30 días.
    final snoozeCounts = <String, int>{};
    for (final event in events) {
      if (event.type == ReminderEventType.snoozed &&
          !event.occurredAt.isBefore(monthAgo)) {
        snoozeCounts.update(
          event.reminderTitle,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final mostSnoozed =
        snoozeCounts.entries
            .where((entry) => entry.value >= 2)
            .map((entry) => (entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));

    return HistoryStats(
      dailyCompletions: daily,
      mostSnoozed: mostSnoozed.take(3).toList(),
      totalCompleted: completions.length,
      completedThisWeek: completions
          .where((e) => !e.occurredAt.isBefore(now.startOfWeek))
          .length,
      currentStreak: _currentStreak(days, now),
      bestStreak: _bestStreak(days),
      onTimeRate: rated.isEmpty
          ? null
          : rated.where((e) => e.onTime!).length / rated.length,
      snoozedLast30Days: events
          .where(
            (e) =>
                e.type == ReminderEventType.snoozed &&
                !e.occurredAt.isBefore(monthAgo),
          )
          .length,
    );
  }

  final int totalCompleted;
  final int completedThisWeek;

  /// Días seguidos con al menos una tarea completada. Si hoy aún no hay
  /// ninguna, la racha de ayer sigue viva.
  final int currentStreak;
  final int bestStreak;

  /// Proporción (0–1) completada antes de la hora límite; `null` sin datos.
  final double? onTimeRate;
  final int snoozedLast30Days;

  static const chartDays = 7;

  /// Completados por día, del más antiguo (hace 6 días) a hoy.
  final List<int> dailyCompletions;

  /// Lo que más se pospone (título, veces), mínimo 2 veces en 30 días.
  final List<(String, int)> mostSnoozed;

  static int _currentStreak(Set<DateTime> days, DateTime now) {
    var day = now.startOfDay;
    if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  static int _bestStreak(Set<DateTime> days) {
    final sorted = days.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in sorted) {
      final consecutive =
          previous != null &&
          DateTime(previous.year, previous.month, previous.day + 1) == day;
      run = consecutive ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }
}
