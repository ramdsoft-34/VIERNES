import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_relative_event.dart';

import '../../helpers/builders.dart';

void main() {
  test('entiende cuánto antes y de qué evento', () {
    final a = SpanishRelativeEvent.parse(
      'Recuérdame comprar el regalo dos días antes del cumpleaños de Sofi',
    )!;
    expect(a.offset, const Duration(days: 2));
    expect(a.eventText, 'cumpleaños de Sofi');
    expect(a.task, 'Comprar el regalo');

    final b = SpanishRelativeEvent.parse(
      'avísame media hora antes de la reunión con el jefe',
    )!;
    expect(b.offset, const Duration(minutes: 30));
    expect(b.eventText, 'reunión con el jefe');
    expect(b.task, isEmpty);

    expect(SpanishRelativeEvent.parse('mañana a las 8 correr'), isNull);
  });

  test('busca el evento en la agenda', () {
    final now = DateTime(2026, 10);
    final reminders = [
      buildReminder(
        id: 'a',
        title: 'Pagar arriendo',
        dueAt: DateTime(2026, 10, 5),
      ),
      buildReminder(
        id: 'b',
        title: 'Cumpleaños de Sofi',
        dueAt: DateTime(2026, 10, 10),
      ),
    ];
    expect(
      SpanishRelativeEvent.findEvent(
        'el cumpleaños de Sofi',
        reminders,
        now,
      )?.id,
      'b',
    );
    expect(SpanishRelativeEvent.findEvent('la boda', reminders, now), isNull);
  });
}
