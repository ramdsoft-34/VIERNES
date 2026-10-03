import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/platform/device_data.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Convierte los cumpleaños de los contactos en recordatorios que se
/// repiten cada año, con un aviso previo opcional («Se acerca el cumpleaños
/// de Sofi», N días antes).
class BirthdayImporter {
  BirthdayImporter({
    required this._prefs,
    required this._create,
    required this._now,
  });

  final SharedPreferences _prefs;
  final Future<Result<Reminder>> Function(ReminderDraft draft) _create;
  final DateTime Function() _now;

  static const _importedKey = 'birthdays.imported';

  /// Claves de los cumpleaños ya agregados (aunque luego se borren, no se
  /// vuelven a agregar solos).
  Set<String> imported() => (_prefs.getStringList(_importedKey) ?? []).toSet();

  /// Los que aún no están en la agenda.
  List<ContactBirthday> pending(List<ContactBirthday> all) {
    final done = imported();
    return [
      for (final b in all)
        if (!done.contains(b.key)) b,
    ];
  }

  /// Agrega [birthdays]. Devuelve cuántos se agregaron.
  Future<int> importAll(
    List<ContactBirthday> birthdays, {
    required DayTime time,
    required int daysBefore,
  }) async {
    final done = imported();
    var added = 0;
    for (final birthday in birthdays) {
      if (done.contains(birthday.key)) continue;
      final ok = await _importOne(birthday, time: time, daysBefore: daysBefore);
      if (!ok) continue;
      done.add(birthday.key);
      added++;
      await _prefs.setStringList(_importedKey, done.toList());
    }
    return added;
  }

  Future<bool> _importOne(
    ContactBirthday birthday, {
    required DayTime time,
    required int daysBefore,
  }) async {
    final now = _now();
    final due = birthday.next(now, hour: time.hour, minute: time.minute);
    final result = await _create(
      ReminderDraft(
        title: SpanishSpeech.birthdayTitle(birthday.name),
        dueAt: due.isAfter(now) ? due : _nextYear(birthday, due),
        recurrence: Recurrence.yearly(birthday.day),
        category: ReminderCategory.personal,
        notes: birthday.year == null ? null : 'Nació en ${birthday.year}',
      ),
    );
    if (result is Err) return false;

    if (daysBefore > 0) {
      var before = due.addDays(-daysBefore);
      if (!before.isAfter(now)) {
        before = _nextYear(birthday, due).addDays(-daysBefore);
      }
      await _create(
        ReminderDraft(
          title: SpanishSpeech.birthdaySoonTitle(birthday.name),
          dueAt: before,
          recurrence: Recurrence.yearly(before.day),
          category: ReminderCategory.personal,
          notes: 'Faltan $daysBefore ${daysBefore == 1 ? 'día' : 'días'}',
        ),
      );
    }
    return true;
  }

  static DateTime _nextYear(ContactBirthday birthday, DateTime due) =>
      birthday.next(DateTime(due.year + 1), hour: due.hour, minute: due.minute);
}
