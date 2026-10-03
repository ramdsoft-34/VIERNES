import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';

/// Frases que Viernes dice (y muestra) durante la conversación.
///
/// Están pensadas para sonar naturales al leerse con voz ("a las 2 de la
/// tarde" en lugar de "14:00"). Un idioma nuevo implica otra clase como esta
/// junto con su intérprete.
abstract final class SpanishSpeech {
  static const listening = 'Te escucho';
  static const noSpeech = 'No te escuché, dime qué necesitas recordar';
  static const gaveUp = 'No te escuché. Cuando quieras, aquí estoy.';
  static const askTitle = '¿Qué quieres que te recuerde?';
  static const askWhen = '¿Para cuándo te lo recuerdo?';
  static const askTime = '¿A qué hora?';
  static const askWhatToChange = '¿Qué quieres cambiar?';
  static const pastTime = 'Esa hora ya pasó. ¿Para cuándo lo dejo?';
  static const didNotUnderstand =
      'No entendí bien. Puedes decir, por ejemplo: mañana a las 8 entregar '
      'el informe.';
  static const cancelled = 'Listo, no guardé nada.';
  static const tapToConfirm = 'Dime «sí» o toca Guardar.';
  static const unavailable =
      'El reconocimiento de voz no está disponible en este teléfono.';
  static const permissionDenied =
      'Necesito permiso para usar el micrófono. Puedes darlo en los ajustes '
      'del teléfono.';

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// "a las 2 y media de la tarde", "a la 1 del mediodía".
  static String time(DateTime t) {
    final h24 = t.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final hour = h12 == 1 ? 'a la 1' : 'a las $h12';
    final minutes = switch (t.minute) {
      0 => '',
      15 => ' y cuarto',
      30 => ' y media',
      final m => ' y $m',
    };
    final period = switch (h24) {
      0 => ' de la noche',
      < 6 => ' de la madrugada',
      < 12 => ' de la mañana',
      12 => ' del mediodía',
      < 19 => ' de la tarde',
      _ => ' de la noche',
    };
    return '$hour$minutes$period';
  }

  /// "hoy", "mañana", "el jueves", "el 20 de octubre".
  static String day(DateTime date, DateTime now) {
    final days = date.startOfDay.difference(now.startOfDay).inDays;
    return switch (days) {
      0 => 'hoy',
      1 => 'mañana',
      2 => 'pasado mañana',
      > 2 && < 7 => 'el ${_weekdays[date.weekday - 1]}',
      _ when date.year == now.year =>
        'el ${date.day} de ${_months[date.month - 1]}',
      _ => 'el ${date.day} de ${_months[date.month - 1]} de ${date.year}',
    };
  }

  static String when(DateTime due, DateTime now) =>
      '${day(due, now)} ${time(due)}';

  static String recurrence(Recurrence r) {
    if (r.interval > 1) {
      return switch (r.frequency) {
        RecurrenceFrequency.daily => 'cada ${r.interval} días',
        RecurrenceFrequency.weekly => 'cada ${r.interval} semanas',
        RecurrenceFrequency.monthly => 'cada ${r.interval} meses',
        _ => '',
      };
    }
    return switch (r.frequency) {
      RecurrenceFrequency.none => '',
      RecurrenceFrequency.daily => 'todos los días',
      RecurrenceFrequency.weekdays => 'de lunes a viernes',
      RecurrenceFrequency.weekly when r.weekdays.isNotEmpty =>
        'todos los ${_joinList(_dayNames(r.weekdays))}',
      RecurrenceFrequency.weekly => 'cada semana',
      RecurrenceFrequency.monthly => 'cada mes',
      RecurrenceFrequency.yearly => 'cada año',
    };
  }

  static String lead(Duration lead) {
    if (lead == Duration.zero) return 'Te aviso a esa hora';
    if (lead.inDays >= 1 && lead.inHours % 24 == 0) {
      return lead.inDays == 1
          ? 'Te aviso un día antes'
          : 'Te aviso ${lead.inDays} días antes';
    }
    if (lead.inMinutes >= 60 && lead.inMinutes % 60 == 0) {
      return lead.inHours == 1
          ? 'Te aviso una hora antes'
          : 'Te aviso ${lead.inHours} horas antes';
    }
    return 'Te aviso ${lead.inMinutes} minutos antes';
  }

  /// "Entregar el informe, mañana a las 8 de la mañana. Te aviso 30 minutos
  /// antes. ¿Lo guardo?"
  static String confirmation({
    required String title,
    required DateTime due,
    required Duration leadTime,
    required Recurrence recurrence,
    required DateTime now,
  }) {
    final repeat = recurrence.repeats
        ? ', ${SpanishSpeech.recurrence(recurrence)}'
        : '';
    return '$title, ${when(due, now)}$repeat. ${lead(leadTime)}. '
        '¿Lo guardo?';
  }

  static String saved(DateTime remindAt, DateTime now) =>
      'Listo. Te lo recuerdo ${when(remindAt, now)}.';

  /// Respuesta a "¿qué tengo hoy?".
  static String agenda({
    required List<Reminder> reminders,
    required DateTime from,
    required bool isWeek,
    required DateTime now,
  }) {
    final label = isWeek
        ? (from.isBefore(now.startOfWeek.addDays(7))
              ? 'esta semana'
              : 'la próxima semana')
        : day(from, now);
    if (reminders.isEmpty) return 'No tienes pendientes para $label.';
    const limit = 5;
    final items = reminders.take(limit).map((r) {
      final at = isWeek ? when(r.dueAt, now) : time(r.dueAt);
      return '${_inSentence(r.title)} $at';
    }).toList();
    final count = reminders.length;
    final intro = count == 1
        ? 'Para $label tienes 1 pendiente'
        : 'Para $label tienes $count pendientes';
    final more = count > limit ? ', entre otros' : '';
    return '${_capitalize(intro)}: ${_joinList(items)}$more.';
  }

  static List<String> _dayNames(Set<int> weekdays) =>
      (weekdays.toList()..sort()).map((d) => _weekdays[d - 1]).toList();

  static const morningSummaryTitle = 'Buenos días ☀️';

  /// "Hoy tienes 3 pendientes: entregar el informe a las 8 de la mañana…"
  static String morningSummary(List<(String title, DateTime at)> items) {
    const limit = 4;
    final parts = items
        .take(limit)
        .map((i) => '${_inSentence(i.$1)} ${time(i.$2)}')
        .toList();
    final count = items.length;
    final intro = count == 1
        ? 'Hoy tienes 1 pendiente'
        : 'Hoy tienes $count pendientes';
    final more = count > limit ? ', entre otros' : '';
    return '$intro: ${_joinList(parts)}$more.';
  }

  static const nightSummaryTitle = 'Resumen del día';

  /// "Quedaron 2 sin confirmar: llamar a Juan y pagar la luz. ¿Las paso a
  /// mañana?"
  static String nightSummary(List<String> titles) {
    const limit = 4;
    final names = titles.take(limit).map(_inSentence).toList();
    final count = titles.length;
    final intro = count == 1
        ? 'Quedó 1 sin confirmar'
        : 'Quedaron $count sin confirmar';
    final question = count == 1 ? '¿La paso a mañana?' : '¿Las paso a mañana?';
    return '$intro: ${_joinList(names)}. $question';
  }

  /// Título en medio de una frase: "Llamar a Juan" → "llamar a Juan".
  /// Solo cambia la primera letra (respeta nombres) y no toca siglas
  /// ("EPS", "PDF").
  static String _inSentence(String title) {
    if (title.length < 2) return title.toLowerCase();
    final second = title[1];
    final isAcronym =
        second == second.toUpperCase() && second != second.toLowerCase();
    return isAcronym ? title : title[0].toLowerCase() + title.substring(1);
  }

  static String _joinList(List<String> items) {
    if (items.length <= 1) return items.join();
    return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
