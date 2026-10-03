import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';

import '../../helpers/builders.dart';

void main() {
  final now = DateTime(2026, 10, 1, 10); // jueves

  test('horas habladas', () {
    expect(SpanishSpeech.time(DateTime(2026, 1, 1, 8)), 'a las 8 de la mañana');
    expect(
      SpanishSpeech.time(DateTime(2026, 1, 1, 14, 30)),
      'a las 2 y media de la tarde',
    );
    expect(
      SpanishSpeech.time(DateTime(2026, 1, 1, 13, 15)),
      'a la 1 y cuarto de la tarde',
    );
    expect(
      SpanishSpeech.time(DateTime(2026, 1, 1, 12)),
      'a las 12 del mediodía',
    );
    expect(
      SpanishSpeech.time(DateTime(2026, 1, 1, 21, 5)),
      'a las 9 y 5 de la noche',
    );
    expect(SpanishSpeech.time(DateTime(2026)), 'a las 12 de la noche');
  });

  test('días hablados', () {
    expect(SpanishSpeech.day(DateTime(2026, 10, 1, 20), now), 'hoy');
    expect(SpanishSpeech.day(DateTime(2026, 10, 2), now), 'mañana');
    expect(SpanishSpeech.day(DateTime(2026, 10, 5), now), 'el lunes');
    expect(SpanishSpeech.day(DateTime(2026, 10, 20), now), 'el 20 de octubre');
  });

  test('confirmación', () {
    expect(
      SpanishSpeech.confirmation(
        title: 'Entregar el informe',
        due: DateTime(2026, 10, 2, 8),
        leadTime: const Duration(minutes: 30),
        recurrence: Recurrence.none,
        now: now,
      ),
      'Entregar el informe, mañana a las 8 de la mañana. '
      'Te aviso 30 minutos antes. ¿Lo guardo?',
    );
    expect(
      SpanishSpeech.recurrence(Recurrence.weekly(const {1, 3})),
      'todos los lunes y miércoles',
    );
  });

  test('respeta nombres propios y siglas en medio de la frase', () {
    expect(
      SpanishSpeech.nightSummary(['Llamar a Juan', 'EPS: pedir cita']),
      'Quedaron 2 sin confirmar: llamar a Juan y EPS: pedir cita. '
      '¿Las paso a mañana?',
    );
  });

  test('agenda', () {
    expect(
      SpanishSpeech.agenda(
        reminders: const [],
        from: DateTime(2026, 10),
        isWeek: false,
        now: now,
      ),
      'No tienes pendientes para hoy.',
    );
    expect(
      SpanishSpeech.agenda(
        reminders: [
          buildReminder(title: 'Reunión', dueAt: DateTime(2026, 10, 1, 14)),
          buildReminder(
            id: 'b',
            title: 'Llamar a mamá',
            dueAt: DateTime(2026, 10, 1, 18),
          ),
        ],
        from: DateTime(2026, 10),
        isWeek: false,
        now: now,
      ),
      'Para hoy tienes 2 pendientes: reunión a las 2 de la tarde y '
      'llamar a mamá a las 6 de la tarde.',
    );
  });
}
