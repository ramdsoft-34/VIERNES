import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/birthdays/application/birthday_importer.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';

void main() {
  group('datos del teléfono', () {
    test('lee las fechas de cumpleaños de Android', () {
      final full = parseBirthday('Sofi', '1995-03-14')!;
      expect((full.month, full.day, full.year), (3, 14, 1995));

      final noYear = parseBirthday('Mamá', '--12-08')!;
      expect((noYear.month, noYear.day, noYear.year), (12, 8, null));

      final slash = parseBirthday('Juan', '07/02/1980')!;
      expect((slash.month, slash.day, slash.year), (2, 7, 1980));

      expect(parseBirthday('Ana', '1604-05-01')!.year, isNull);
      expect(parseBirthday('', '1995-03-14'), isNull);
      expect(parseBirthday('X', 'ayer'), isNull);
      expect(parseBirthday('X', '2000-13-40'), isNull);
    });

    test('próximo cumpleaños y edad', () {
      const sofi = ContactBirthday(name: 'Sofi', month: 3, day: 14, year: 1995);
      final now = DateTime(2026, 10, 3, 10);
      expect(sofi.next(now), DateTime(2027, 3, 14, 8));
      expect(sofi.ageOn(sofi.next(now)), 32);
      // Hoy cuenta aunque la hora ya pasó (el importador decide).
      expect(
        const ContactBirthday(name: 'Hoy', month: 10, day: 3).next(now),
        DateTime(2026, 10, 3, 8),
      );
      // 29 de febrero en un año no bisiesto.
      expect(
        const ContactBirthday(name: 'B', month: 2, day: 29).next(now),
        DateTime(2027, 2, 28, 8),
      );
    });

    test('eventos del calendario (todo el día conserva la fecha)', () {
      final event = CalendarEvent.fromMap({
        'title': ' Viaje ',
        'start': DateTime.utc(2026, 10, 5).millisecondsSinceEpoch,
        'end': DateTime.utc(2026, 10, 6).millisecondsSinceEpoch,
        'allDay': true,
        'calendar': 'Personal',
        'location': '',
      });
      expect(event.title, 'Viaje');
      expect(event.start, DateTime(2026, 10, 5));
      expect(event.allDay, isTrue);
      expect(event.location, isNull);
      expect(CalendarEvent.fromMap(const {'title': null}).title, 'Evento');
    });
  });

  group('BirthdayImporter', () {
    late BirthdayImporter importer;
    late List<ReminderDraft> created;
    final now = DateTime(2026, 10, 3, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      created = [];
      importer = BirthdayImporter(
        prefs: await SharedPreferences.getInstance(),
        create: (draft) async {
          created.add(draft);
          return Result.ok(
            Reminder(
              id: 'b${created.length}',
              title: draft.title,
              dueAt: draft.dueAt,
              createdAt: now,
              updatedAt: now,
            ),
          );
        },
        now: () => now,
      );
    });

    test('crea el cumpleaños cada año y el aviso previo', () async {
      const sofi = ContactBirthday(
        name: 'Sofi',
        month: 10,
        day: 20,
        year: 1995,
      );

      final added = await importer.importAll(
        const [sofi],
        time: const DayTime(9, 0),
        daysBefore: 2,
      );

      expect(added, 1);
      expect(created, hasLength(2));
      expect(created[0].title, 'Cumpleaños de Sofi');
      expect(created[0].dueAt, DateTime(2026, 10, 20, 9));
      expect(created[0].recurrence.frequency, RecurrenceFrequency.yearly);
      expect(created[0].notes, 'Nació en 1995');
      expect(created[1].title, 'Se acerca el cumpleaños de Sofi');
      expect(created[1].dueAt, DateTime(2026, 10, 18, 9));
    });

    test('no repite los que ya agregó', () async {
      const mama = ContactBirthday(name: 'Mamá', month: 12, day: 8);
      await importer.importAll(
        const [mama],
        time: const DayTime(8, 0),
        daysBefore: 0,
      );
      expect(importer.pending(const [mama]), isEmpty);

      final again = await importer.importAll(
        const [mama],
        time: const DayTime(8, 0),
        daysBefore: 0,
      );
      expect(again, 0);
      expect(created, hasLength(1));
    });

    test('si hoy ya pasó la hora, queda para el próximo año', () async {
      const hoy = ContactBirthday(name: 'Leo', month: 10, day: 3);
      await importer.importAll(
        const [hoy],
        time: const DayTime(8, 0),
        daysBefore: 0,
      );
      expect(created.single.dueAt, DateTime(2027, 10, 3, 8));
    });
  });
}
