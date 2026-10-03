import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/settings/domain/app_settings.dart';
import 'package:viernes/features/summaries/domain/daily_briefing.dart';
import 'package:viernes/features/summaries/domain/summary_planner.dart';

import '../../helpers/builders.dart';

void main() {
  // Jueves 1 de octubre de 2026, 7:00 a. m.
  final now = DateTime(2026, 10, 1, 7);
  final meeting = CalendarEvent(
    title: 'Reunión con Ana',
    start: DateTime(2026, 10, 1, 15),
    end: DateTime(2026, 10, 1, 16),
  );

  group('DailyBriefing', () {
    test('lo de hoy, lo vencido, el calendario y lo que se acerca', () {
      final text = DailyBriefing.compose(
        active: [
          buildReminder(
            id: 'a',
            title: 'Pagar la luz',
            dueAt: now.add(
              const Duration(hours: 2),
            ),
          ),
          buildReminder(
            id: 'b',
            title: 'Llamar al banco',
            dueAt: DateTime(2026, 9, 29, 9),
          ),
          buildReminder(
            id: 'c',
            title: 'Cumpleaños de Sofi',
            dueAt: DateTime(2026, 10, 4, 8),
          ),
          buildReminder(
            id: 'd',
            title: 'Algo normal',
            dueAt: DateTime(2026, 10, 5, 8),
          ),
        ],
        now: now,
        events: [meeting],
      );

      expect(text, startsWith('Buenos días.'));
      expect(text, contains('Hoy tienes 1 pendiente: pagar la luz a las 9'));
      expect(text, contains('quedó 1 pendiente de días anteriores'));
      expect(text, contains('En tu calendario: reunión con Ana a las 3'));
      expect(text, contains('Se acerca: cumpleaños de Sofi el domingo'));
      expect(text, isNot(contains('Algo normal')));
    });

    test('día libre', () {
      expect(
        DailyBriefing.compose(active: const [], now: now),
        'Buenos días. Hoy no tienes pendientes. ¡Que tengas un buen día!',
      );
    });

    test('en modo conducción es más corto', () {
      final text = DailyBriefing.compose(
        active: [
          buildReminder(
            title: 'Cumpleaños de Sofi',
            dueAt: DateTime(2026, 10, 3, 8),
            priority: ReminderPriority.high,
          ),
        ],
        now: now,
        short: true,
      );
      expect(text, isNot(contains('Se acerca')));
    });

    test('reconoce cuando piden el resumen', () {
      for (final phrase in [
        'buenos días',
        'Buenos días, Viernes',
        'dame el resumen del día',
        '¿cómo está mi día?',
        'qué tal viene mi día de hoy',
        'resumen del día',
      ]) {
        expect(SpanishBriefingRequest.matches(phrase), isTrue, reason: phrase);
      }
      for (final phrase in [
        'buenos días recuérdame llamar a Juan',
        'recuérdame el resumen del informe mañana',
      ]) {
        expect(SpanishBriefingRequest.matches(phrase), isFalse, reason: phrase);
      }
    });
  });

  group('calendario en las respuestas', () {
    test('«¿qué tengo hoy?» incluye los eventos', () {
      final text = SpanishSpeech.agenda(
        reminders: const [],
        from: DateTime(2026, 10),
        isWeek: false,
        now: now,
        events: [meeting],
      );
      expect(
        text,
        'No tienes pendientes para hoy. En tu calendario: reunión con Ana a '
        'las 3 de la tarde.',
      );
    });

    test('el resumen de la mañana sale aunque solo haya eventos', () {
      final plans = SummaryPlanner.plan(
        active: const [],
        settings: const AppSettings(nightSummaryEnabled: false),
        now: DateTime(2026, 10, 1, 6),
        events: [meeting],
      );
      final morning = plans.single;
      expect(morning.at, DateTime(2026, 10, 1, 7));
      expect(morning.body, contains('Hoy no tienes pendientes.'));
      expect(morning.body, contains('reunión con Ana'));
      expect(morning.count, 1);
    });
  });
}
