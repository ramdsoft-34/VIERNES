import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';

void main() {
  group('Recurrence.nextAfter', () {
    // Jueves 1 de octubre de 2026, 8:00.
    final thursday = DateTime(2026, 10, 1, 8);

    test('none no tiene siguiente ocurrencia', () {
      expect(Recurrence.none.nextAfter(thursday), isNull);
    });

    test('daily suma un día y conserva la hora', () {
      expect(Recurrence.daily.nextAfter(thursday), DateTime(2026, 10, 2, 8));
    });

    test('daily cada 3 días', () {
      const every3 = Recurrence(
        frequency: RecurrenceFrequency.daily,
        interval: 3,
      );
      expect(every3.nextAfter(thursday), DateTime(2026, 10, 4, 8));
    });

    test('weekdays salta el fin de semana', () {
      final friday = DateTime(2026, 10, 2, 8);
      expect(
        Recurrence.weekdaysOnly.nextAfter(friday),
        DateTime(2026, 10, 5, 8),
      );
    });

    test('weekly sin días suma 7 días', () {
      expect(
        const Recurrence(
          frequency: RecurrenceFrequency.weekly,
        ).nextAfter(thursday),
        DateTime(2026, 10, 8, 8),
      );
    });

    test('weekly con días busca el siguiente día marcado', () {
      final mondayWednesday = Recurrence.weekly(const {
        DateTime.monday,
        DateTime.wednesday,
      });
      // Jueves → lunes siguiente.
      expect(mondayWednesday.nextAfter(thursday), DateTime(2026, 10, 5, 8));
      // Lunes → miércoles de la misma semana.
      expect(
        mondayWednesday.nextAfter(DateTime(2026, 10, 5, 8)),
        DateTime(2026, 10, 7, 8),
      );
    });

    test('weekly cada 2 semanas salta una semana al cambiar de semana', () {
      final biweekly = Recurrence.weekly(const {DateTime.monday}, interval: 2);
      expect(
        biweekly.nextAfter(DateTime(2026, 10, 5, 8)),
        DateTime(2026, 10, 19, 8),
      );
    });

    test('monthly recorta al último día y recupera el día original', () {
      final day31 = Recurrence.monthly(31);
      final jan31 = DateTime(2026, 1, 31, 9);
      final feb = day31.nextAfter(jan31)!;
      expect(feb, DateTime(2026, 2, 28, 9));
      expect(day31.nextAfter(feb), DateTime(2026, 3, 31, 9));
    });

    test('yearly en 29 de febrero cae el 28 en años no bisiestos', () {
      final leap = Recurrence.yearly(29);
      expect(
        leap.nextAfter(DateTime(2028, 2, 29, 7)),
        DateTime(2029, 2, 28, 7),
      );
    });
  });

  group('Recurrence encode/decode', () {
    test('ida y vuelta conserva la regla', () {
      final rules = [
        Recurrence.none,
        Recurrence.daily,
        Recurrence.weekdaysOnly,
        Recurrence.weekly(const {1, 3, 5}, interval: 2),
        Recurrence.monthly(15),
        Recurrence.yearly(29),
      ];
      for (final rule in rules) {
        expect(Recurrence.decode(rule.encode()), rule, reason: rule.encode());
      }
    });

    test('valores vacíos o corruptos se tratan como sin repetición', () {
      expect(Recurrence.decode(null), Recurrence.none);
      expect(Recurrence.decode(''), Recurrence.none);
      expect(Recurrence.decode('FREQ=NUNCA'), Recurrence.none);
    });

    test('ignora días inválidos en BYDAY', () {
      expect(
        Recurrence.decode('FREQ=WEEKLY;INTERVAL=1;BYDAY=1,x,3').weekdays,
        {1, 3},
      );
    });
  });
}
