import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/calendar/domain/calendar_occurrences.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';

/// Resumen hablado del día («Buenos días. Hoy tienes 3 pendientes…»).
abstract final class DailyBriefing {
  /// Cuántos días adelante se miran para «se acerca».
  static const soonDays = 7;

  static String compose({
    required Iterable<Reminder> active,
    required DateTime now,
    List<CalendarEvent> events = const [],
    bool short = false,
  }) {
    final today = now.startOfDay;
    final tomorrow = today.addDays(1);
    final pending = active.where((r) => r.isActive).toList();

    final todayItems =
        CalendarOccurrences.expand(pending, today, tomorrow)[today] ??
        const <Occurrence>[];
    final overdue = pending
        .where((r) => !r.recurrence.repeats && r.dueAt.isBefore(today))
        .length;

    // Lo importante de los próximos días: cumpleaños y prioridad alta.
    final soonByDay = CalendarOccurrences.expand(
      pending,
      tomorrow,
      today.addDays(soonDays + 1),
    );
    final soon = <(String, DateTime)>[
      for (final day in soonByDay.keys.toList()..sort())
        for (final o in soonByDay[day]!)
          if (isNotable(o.reminder)) (o.reminder.title, o.at),
    ];

    return SpanishSpeech.briefing(
      now: now,
      today: [for (final o in todayItems) (o.reminder.title, o.at)],
      overdue: overdue,
      events: [
        for (final e in events)
          if (e.start.isBefore(tomorrow) && !e.end.isBefore(today)) e,
      ],
      soon: soon,
      short: short,
    );
  }

  /// Cumpleaños, aniversarios o algo marcado como importante.
  static bool isNotable(Reminder reminder) {
    final title = reminder.title.toLowerCase();
    return reminder.priority.isAtLeastHigh ||
        title.contains('cumpleaños') ||
        title.contains('aniversario');
  }
}

/// Detecta cuándo piden el resumen del día por voz.
abstract final class SpanishBriefingRequest {
  static final _pattern = RegExp(
    r'^(?:(?:hola|oye|ey)\s+)?(?:viernes\W*\s*)?(?:'
    r'buen(?:os|as)\s+d[ií]as?|'
    r'(?:dame|hazme|leeme|léeme|dime)\s+(?:el\s+|mi\s+)?resumen(?:\s+del\s+d[ií]a)?|'
    r'(?:el\s+|mi\s+)?resumen\s+del\s+d[ií]a|'
    r'(?:c[oó]mo|qu[eé]\s+tal)\s+(?:est[aá]|viene|pinta)\s+(?:mi|el)\s+d[ií]a(?:\s+de\s+hoy)?|'
    r'qu[eé]\s+(?:hay|tengo)\s+para\s+hoy\s+en\s+general'
    r')(?:\W+viernes)?\W*$',
    caseSensitive: false,
  );

  static bool matches(String text) =>
      _pattern.hasMatch(text.trim().replaceFirst(RegExp('^[¿¡]+'), ''));
}
