import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/voice_assistant/domain/voice_draft_builder.dart';

void main() {
  final now = DateTime(2026, 10, 1, 10);
  const defaultLead = Duration(minutes: 15);

  Duration lead(ParsedReminder p) => VoiceDraftBuilder.leadTime(
    p,
    due: p.resolveDue(now)!,
    now: now,
    defaultLead: defaultLead,
  );

  test('usa la anticipación de los ajustes por defecto', () {
    expect(
      lead(
        ParsedReminder(date: DateTime(2026, 10, 2), time: const DayTime(8, 0)),
      ),
      defaultLead,
    );
  });

  test('un límite ("antes de") avisa con al menos 30 minutos', () {
    expect(
      lead(
        ParsedReminder(
          date: DateTime(2026, 10, 2),
          time: const DayTime(8, 0),
          isDeadline: true,
        ),
      ),
      const Duration(minutes: 30),
    );
  });

  test('la anticipación pedida manda', () {
    expect(
      lead(
        ParsedReminder(
          date: DateTime(2026, 10, 2),
          time: const DayTime(8, 0),
          isDeadline: true,
          leadTime: const Duration(minutes: 5),
        ),
      ),
      const Duration(minutes: 5),
    );
  });

  test('"en 20 minutos" avisa a la hora exacta', () {
    expect(
      lead(ParsedReminder(exactDue: now.add(const Duration(minutes: 20)))),
      Duration.zero,
    );
  });

  test('nunca avisa en el pasado', () {
    // Faltan 10 minutos: el aviso no puede ser 15 minutos antes.
    expect(
      lead(
        ParsedReminder(
          date: DateTime(2026, 10),
          time: const DayTime(10, 10),
        ),
      ),
      const Duration(minutes: 10),
    );
  });

  test('completa el día de una repetición mensual', () {
    expect(
      VoiceDraftBuilder.recurrence(
        const Recurrence(frequency: RecurrenceFrequency.monthly),
        DateTime(2026, 10, 15, 9),
      ),
      Recurrence.monthly(15),
    );
  });

  test('borrador sin hora usa las 9:00 del día mencionado', () {
    final draft = VoiceDraftBuilder.draft(
      ParsedReminder(title: 'Cita', date: DateTime(2026, 10, 20)),
      now: now,
      defaultLead: defaultLead,
      utterances: const ['el día 20 tengo una cita'],
    );
    expect(draft.dueAt, DateTime(2026, 10, 20, 9));
  });
}
