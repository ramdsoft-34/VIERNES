import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Jueves 1 de octubre de 2026, 10:00 a. m.
final now = DateTime(2026, 10, 1, 10);
const interpreter = SpanishRuleInterpreter();

Interpretation parse(String text, {MissingSlot? expecting}) =>
    interpreter.parse(text, now, expecting: expecting);

ParsedReminder reminder(String text) => parse(text).reminder;

DateTime? due(String text) => reminder(text).resolveDue(now);

void main() {
  group('frases de la idea original', () {
    test('"mañana antes de las 8 tengo que entregar el informe"', () {
      final r = reminder(
        'Viernes, mañana antes de las 8 tengo que entregar el informe.',
      );
      expect(r.title, 'Entregar el informe');
      expect(r.resolveDue(now), DateTime(2026, 10, 2, 8));
      expect(r.isDeadline, isTrue);
      expect(r.category, ReminderCategory.work);
    });

    test('"el día 20 tengo una cita" pide la hora', () {
      final r = reminder('Viernes, el día 20 tengo una cita.');
      expect(r.title, 'Cita');
      expect(r.date, DateTime(2026, 10, 20));
      expect(r.missing(now), [MissingSlot.time]);
    });

    test('"a las 2 de la tarde tengo reunión"', () {
      final r = reminder('Viernes, a las 2 de la tarde tengo reunión.');
      expect(r.title, 'Reunión');
      expect(r.resolveDue(now), DateTime(2026, 10, 1, 14));
      expect(r.missing(now), isEmpty);
    });
  });

  group('horas', () {
    final cases = <String, DayTime>{
      'a las 3 de la tarde llamar a Juan': const DayTime(15, 0),
      'a las 8 de la mañana correr': const DayTime(8, 0),
      'a las 8 y media de la noche cenar': const DayTime(20, 30),
      'a las 10 menos cuarto de la mañana': const DayTime(9, 45),
      'a la una de la tarde almorzar': const DayTime(13, 0),
      'a las 7:30 pm ver el partido': const DayTime(19, 30),
      'a las 14:45 entregar': const DayTime(14, 45),
      'a las tres y veinte de la tarde': const DayTime(15, 20),
      'tomar la pastilla 9 pm': const DayTime(21, 0),
      'al mediodía almorzar con Ana': const DayTime(12, 0),
      'a las 12 de la noche apagar': const DayTime(0, 0),
      'cita médica a las 4': const DayTime(16, 0),
    };
    for (final MapEntry(key: text, value: expected) in cases.entries) {
      test(text, () => expect(reminder(text).effectiveTime, expected));
    }

    test('hora ambigua de la mañana ya pasada se toma en la noche', () {
      // Son las 10 a. m.: "a las 8" sin más contexto es esta noche.
      expect(due('a las 8 llamar a mamá'), DateTime(2026, 10, 1, 20));
    });

    test('"a las 9 y cuarto" ya pasada hoy es en la noche', () {
      expect(due('a las 9 y cuarto reunión'), DateTime(2026, 10, 1, 21, 15));
    });

    test('al corregir la hora se respeta el día ya elegido', () {
      final draft = reminder('mañana a las 8 correr');
      final corrected = draft.merge(reminder('a las 9'));
      expect(corrected.resolveDue(now), DateTime(2026, 10, 2, 9));
    });

    test('hora ambigua de la mañana aún por venir se respeta', () {
      expect(due('a las 11 llamar a mamá'), DateTime(2026, 10, 1, 11));
    });

    test('con fecha futura la hora ambigua queda en la mañana', () {
      expect(due('mañana a las 8 correr'), DateTime(2026, 10, 2, 8));
    });

    test('la franja del día corrige una hora ambigua', () {
      expect(
        due('mañana a las 8 llamar a Juan en la noche'),
        DateTime(2026, 10, 2, 20),
      );
    });

    test('hora ya pasada sin fecha se pasa a mañana', () {
      expect(due('a las 9 de la mañana correr'), DateTime(2026, 10, 2, 9));
    });

    test('"antes de" marca la hora como límite', () {
      expect(reminder('antes de las 5 pagar la luz').isDeadline, isTrue);
      expect(reminder('a más tardar a las 5 pagar').isDeadline, isTrue);
      expect(reminder('a las 5 pagar la luz').isDeadline, isFalse);
    });

    test('"a las 2 y una reunión" no confunde "una" con minutos', () {
      final r = reminder('a las 2 y una reunión con ventas');
      expect(r.time, const DayTime(14, 0));
    });

    test('"a mi mamá" no se confunde con a. m.', () {
      final r = reminder('a las 8 a mi mamá le compro flores');
      expect(r.title, contains('mamá'));
    });
  });

  group('franjas del día', () {
    test('"esta noche" es hoy a las 8 p. m.', () {
      expect(due('esta noche lavar la ropa'), DateTime(2026, 10, 1, 20));
    });

    test('"mañana en la tarde"', () {
      expect(due('mañana en la tarde ir al banco'), DateTime(2026, 10, 2, 15));
    });

    test('"mañana por la mañana" no confunde las dos "mañana"', () {
      expect(due('mañana por la mañana correr'), DateTime(2026, 10, 2, 9));
    });

    test('"mañana temprano"', () {
      expect(due('mañana temprano sacar al perro'), DateTime(2026, 10, 2, 7));
    });
  });

  group('fechas', () {
    test('hoy, mañana y pasado mañana', () {
      expect(reminder('hoy llamar').date, DateTime(2026, 10));
      expect(reminder('mañana llamar').date, DateTime(2026, 10, 2));
      expect(reminder('pasado mañana llamar').date, DateTime(2026, 10, 3));
    });

    test('días de la semana', () {
      // Hoy es jueves.
      expect(reminder('el lunes llamar').date, DateTime(2026, 10, 5));
      expect(reminder('el próximo sábado').date, DateTime(2026, 10, 3));
      expect(reminder('el jueves pagar').date, DateTime(2026, 10, 8));
      expect(reminder('este jueves pagar').date, DateTime(2026, 10));
      expect(
        reminder('el martes de la próxima semana').date,
        DateTime(2026, 10, 6),
      );
    });

    test('día y mes', () {
      expect(reminder('el 20 de octubre').date, DateTime(2026, 10, 20));
      expect(reminder('el 5 de enero').date, DateTime(2027, 1, 5));
      expect(
        reminder('el quince de diciembre de 2027').date,
        DateTime(2027, 12, 15),
      );
      expect(reminder('el 24/12 comprar regalos').date, DateTime(2026, 12, 24));
    });

    test('solo el día del mes', () {
      expect(reminder('el día 20 cita').date, DateTime(2026, 10, 20));
      // El 1 ya es hoy; el día 30 de este mes aún no llega.
      expect(reminder('el 30 pagar').date, DateTime(2026, 10, 30));
      expect(reminder('el día primero').date, DateTime(2026, 10));
    });

    test('relativas en días y semanas', () {
      expect(reminder('en 3 días llamar').date, DateTime(2026, 10, 4));
      expect(reminder('dentro de 2 semanas').date, DateTime(2026, 10, 15));
      expect(reminder('la próxima semana').date, DateTime(2026, 10, 5));
    });

    test('fin de mes', () {
      expect(reminder('a fin de mes pagar').date, DateTime(2026, 10, 31));
    });

    test('día inválido no se interpreta como fecha', () {
      expect(reminder('el 31 de noviembre').date, isNull);
    });
  });

  group('tiempo relativo', () {
    test('en minutos y horas', () {
      expect(due('en 20 minutos sacar la ropa'), DateTime(2026, 10, 1, 10, 20));
      expect(due('dentro de 2 horas llamar'), DateTime(2026, 10, 1, 12));
      expect(due('en media hora'), DateTime(2026, 10, 1, 10, 30));
      expect(due('en una hora y media'), DateTime(2026, 10, 1, 11, 30));
      expect(due('en un rato revisar'), DateTime(2026, 10, 1, 10, 30));
    });

    test('el título queda limpio', () {
      expect(
        reminder('recuérdame en 20 minutos sacar la ropa de la lavadora').title,
        'Sacar la ropa de la lavadora',
      );
    });
  });

  group('repetición', () {
    test('todos los días', () {
      final r = reminder(
        'todos los días a las 9 de la noche tomar la pastilla',
      );
      expect(r.recurrence, Recurrence.daily);
      expect(r.title, 'Tomar la pastilla');
      expect(r.category, ReminderCategory.health);
    });

    test('días de la semana', () {
      final r = reminder('todos los lunes y miércoles a las 7 ir al gimnasio');
      expect(r.recurrence, Recurrence.weekly(const {1, 3}));
      expect(r.time, const DayTime(7, 0));
      expect(r.resolveDue(now), DateTime(2026, 10, 5, 7));
    });

    test('"los martes" sin "todos"', () {
      expect(
        reminder('los martes clase de inglés').recurrence,
        Recurrence.weekly(const {2}),
      );
    });

    test('de lunes a viernes', () {
      final r = reminder('de lunes a viernes a las 6 de la mañana despertar');
      expect(r.recurrence, Recurrence.weekdaysOnly);
      expect(r.resolveDue(now), DateTime(2026, 10, 2, 6));
    });

    test('cada mes con día', () {
      final r = reminder('el 5 de cada mes pagar el arriendo');
      expect(r.recurrence, Recurrence.monthly(5));
      expect(r.date, DateTime(2026, 10, 5));
      expect(r.title, 'Pagar el arriendo');
      expect(r.category, ReminderCategory.finance);
    });

    test('cada 15 días y cada 3 días', () {
      expect(
        reminder('cada quince días regar las plantas').recurrence,
        Recurrence.weekly(const {}, interval: 2),
      );
      expect(
        reminder('cada 3 días cambiar el agua').recurrence.interval,
        3,
      );
    });

    test('cada año', () {
      expect(
        reminder(
          'cada año el 3 de mayo cumpleaños de Ana',
        ).recurrence.frequency,
        RecurrenceFrequency.yearly,
      );
    });
  });

  group('prioridad y anticipación', () {
    test('urgente', () {
      final r = reminder('es urgente, mañana a las 9 llamar al banco');
      expect(r.priority, ReminderPriority.urgent);
      expect(r.title, 'Llamar al banco');
    });

    test('importante y sin prisa', () {
      expect(
        reminder('importante: pagar la tarjeta').priority,
        ReminderPriority.high,
      );
      expect(
        reminder('sin prisa, ordenar el closet').priority,
        ReminderPriority.low,
      );
      expect(
        reminder('no es urgente lavar el carro').priority,
        ReminderPriority.low,
      );
    });

    test('anticipación explícita', () {
      expect(
        reminder('mañana a las 3 reunión, avísame 15 minutos antes').leadTime,
        const Duration(minutes: 15),
      );
      expect(
        reminder('el viernes examen, recuérdamelo un día antes').leadTime,
        const Duration(days: 1),
      );
      expect(
        reminder('a las 5 cita con media hora de anticipación').leadTime,
        const Duration(minutes: 30),
      );
    });
  });

  group('título', () {
    final cases = <String, String>{
      'recuérdame que mañana tengo que llamar a mamá': 'Llamar a mamá',
      'no olvides comprar leche hoy en la tarde': 'Comprar leche',
      'tengo cita con el dentista el martes a las 3': 'Cita con el dentista',
      'hay que pagar la luz antes del viernes': 'Pagar la luz',
      'Oye Viernes, por favor apunta revisar el correo a las 4':
          'Revisar el correo',
      'mañana a las 8 tengo que entregar el informe de ventas por favor':
          'Entregar el informe de ventas',
    };
    for (final MapEntry(key: text, value: expected) in cases.entries) {
      test(text, () => expect(reminder(text).title, expected));
    }

    test('conserva tildes y mayúsculas del original', () {
      expect(
        reminder('mañana llamar a María José').title,
        'Llamar a María José',
      );
    });
  });

  group('intención', () {
    test('consulta de agenda de hoy', () {
      final result = parse('¿Qué tengo hoy?');
      expect(result.intent, VoiceIntent.queryAgenda);
      expect(result.agenda!.from, DateTime(2026, 10));
      expect(result.agenda!.to, DateTime(2026, 10, 2));
    });

    test('consulta de mañana y de la semana', () {
      expect(parse('qué tengo mañana').agenda!.from, DateTime(2026, 10, 2));
      final week = parse('cuáles son mis pendientes esta semana').agenda!;
      expect(week.isWeek, isTrue);
      expect(week.to, DateTime(2026, 10, 5));
      final next = parse('qué tengo la próxima semana').agenda!;
      expect(next.from, DateTime(2026, 10, 5));
      expect(next.to, DateTime(2026, 10, 12));
    });

    test('"tengo que" no es una consulta', () {
      expect(
        parse('tengo que llamar a Pedro').intent,
        VoiceIntent.createReminder,
      );
    });

    test('texto vacío o sin contenido', () {
      expect(parse('').intent, VoiceIntent.unknown);
      expect(parse('Viernes').intent, VoiceIntent.unknown);
    });
  });

  group('respuestas cortas', () {
    test('al preguntar la hora acepta solo el número', () {
      expect(
        parse('a las tres', expecting: MissingSlot.time).reminder.time,
        const DayTime(15, 0),
      );
      expect(
        parse('tres', expecting: MissingSlot.time).reminder.time,
        const DayTime(15, 0),
      );
      expect(
        parse('10 de la mañana', expecting: MissingSlot.time).reminder.time,
        const DayTime(10, 0),
      );
    });

    test('sin contexto un número suelto no es una hora', () {
      expect(parse('tres').reminder.time, isNull);
    });
  });

  group('confianza', () {
    test('alta con tarea y momento claros', () {
      expect(parse('mañana a las 8 entregar el informe').confidence, 1.0);
    });

    test('menor si falta la hora', () {
      expect(parse('el día 20 cita').confidence, lessThan(1.0));
    });
  });

  group('repeticiones con fecha final (pruebas en el teléfono)', () {
    test('"por 30 días … a las 7 de la noche" se repite 30 días', () {
      final r = reminder(
        'por 30 días tengo que tomar una pasta así que por 30 días a las 7 '
        'de la noche Recuérdame que tengo que tomar una pasta',
      );
      expect(r.recurrence.frequency, RecurrenceFrequency.daily);
      expect(r.recurrence.until, DateTime(2026, 10, 30));
      expect(r.resolveDue(now), DateTime(2026, 10, 1, 19));
      expect(r.title.toLowerCase(), contains('tomar una pasta'));
      expect(r.title.toLowerCase(), isNot(contains('así que')));
    });

    test('"del 5 al 10 … esos días a las 10 de la mañana"', () {
      final r = reminder(
        'del 5 al 10 tengo parciales entonces esos días a las 10 de la '
        'mañana tienes que estarme recordando que tengo que',
      );
      expect(r.title, 'Parciales');
      expect(r.recurrence.frequency, RecurrenceFrequency.daily);
      expect(r.recurrence.until, DateTime(2026, 10, 10));
      expect(r.resolveDue(now), DateTime(2026, 10, 5, 10));
    });

    test('un rango que ya empezó arranca hoy', () {
      final r = reminder('del 1 al 3 tomar agua a las 6 de la tarde');
      expect(r.resolveDue(now), DateTime(2026, 10, 1, 18));
      expect(r.recurrence.until, DateTime(2026, 10, 3));
    });

    test('"todos los días hasta el 15" pone el último día', () {
      final r = reminder('todos los días hasta el 15 a las 8 pm caminar');
      expect(r.title, 'Caminar');
      expect(r.recurrence.until, DateTime(2026, 10, 15));
    });

    test('"durante dos semanas" cuenta 14 días', () {
      final r = reminder('durante dos semanas a las 9 pm estirar');
      expect(r.recurrence.until, DateTime(2026, 10, 14));
    });
  });

  group('órdenes de alarma y "hazme acuerdo"', () {
    test('"activa una alarma a las 5:30" se llama Alarma', () {
      final r = reminder('activa una alarma a las 5:30 pm');
      expect(r.title, 'Alarma');
      expect(r.resolveDue(now), DateTime(2026, 10, 1, 17, 30));
    });

    test('"hazme acuerdo de llamar a Juan"', () {
      expect(
        reminder('hazme acuerdo de llamar a Juan mañana').title,
        'Llamar a Juan',
      );
    });

    test('"despiértame mañana a las 6"', () {
      expect(reminder('despiértame mañana a las 6 am').title, 'Despertar');
    });
  });
}
