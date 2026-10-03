import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/alerts/domain/notification_ids.dart';
import 'package:viernes/features/calendar/domain/calendar_occurrences.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';

enum SummaryKind { morning, night }

/// Un resumen diario ya redactado y listo para programar.
@immutable
class PlannedSummary {
  const PlannedSummary({
    required this.notificationId,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.count,
  });

  final int notificationId;
  final SummaryKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// Cuántos recordatorios menciona.
  final int count;

  /// Payload de la notificación (para saber qué se tocó).
  String get payload => 'summary:${kind.name}';

  @override
  String toString() => 'PlannedSummary(${kind.name} @ $at: $body)';
}

/// Calcula los resúmenes de los próximos días con lo que se sabe hoy.
///
/// Se recalcula cada vez que cambia un recordatorio, así el texto siempre
/// coincide con la agenda real aunque la app no se abra en varios días.
abstract final class SummaryPlanner {
  /// Días que se programan por adelantado.
  static const days = 7;

  static const int _morningSlot = 0;
  static const int _nightSlot = days;

  /// Ids reservados para resúmenes: no chocan con los de recordatorios.
  static int idFor(SummaryKind kind, int dayOffset) =>
      NotificationIds.reservedBase +
      (kind == SummaryKind.morning ? _morningSlot : _nightSlot) +
      dayOffset;

  static List<int> get allIds => [
    for (var i = 0; i < days * 2; i++) NotificationIds.reservedBase + i,
  ];

  static List<PlannedSummary> plan({
    required Iterable<Reminder> active,
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!settings.morningSummaryEnabled && !settings.nightSummaryEnabled) {
      return const [];
    }
    final today = now.startOfDay;
    final byDay = CalendarOccurrences.expand(
      active.where((r) => r.isActive),
      // Desde ayer: los vencidos de hoy cuentan para el resumen de la noche.
      today.addDays(-1),
      today.addDays(days),
    );

    final plans = <PlannedSummary>[];
    for (var offset = 0; offset < days; offset++) {
      final day = today.addDays(offset);
      final occurrences = byDay[day] ?? const <Occurrence>[];

      if (settings.morningSummaryEnabled) {
        final at = day.withTime(
          settings.morningSummaryTime.hour,
          settings.morningSummaryTime.minute,
        );
        if (at.isAfter(now) && occurrences.isNotEmpty) {
          plans.add(
            PlannedSummary(
              notificationId: idFor(SummaryKind.morning, offset),
              kind: SummaryKind.morning,
              at: at,
              title: SpanishSpeech.morningSummaryTitle,
              body: SpanishSpeech.morningSummary([
                for (final o in occurrences) (o.reminder.title, o.at),
              ]),
              count: occurrences.length,
            ),
          );
        }
      }

      if (settings.nightSummaryEnabled) {
        final at = day.withTime(
          settings.nightSummaryTime.hour,
          settings.nightSummaryTime.minute,
        );
        // Lo que vence ese día antes de la hora del resumen y seguiría
        // pendiente si no se confirma; hoy, también lo vencido de días
        // anteriores.
        final pending = [
          if (offset == 0)
            for (final r in active)
              if (r.isActive &&
                  !r.recurrence.repeats &&
                  r.dueAt.isBefore(today))
                r.title,
          for (final o in occurrences)
            if (o.at.isBefore(at)) o.reminder.title,
        ];
        if (at.isAfter(now) && pending.isNotEmpty) {
          plans.add(
            PlannedSummary(
              notificationId: idFor(SummaryKind.night, offset),
              kind: SummaryKind.night,
              at: at,
              title: SpanishSpeech.nightSummaryTitle,
              body: SpanishSpeech.nightSummary(pending),
              count: pending.length,
            ),
          );
        }
      }
    }
    return plans;
  }
}
