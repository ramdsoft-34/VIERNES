import 'package:viernes/core/platform/device_data.dart';
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

  /// Al cancelar apenas se activa (p. ej. se activó por error).
  static const dismissed = 'Está bien. Aquí estoy si me necesitas.';
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
    final base = _recurrenceBase(r);
    final last = r.until;
    if (base.isEmpty || last == null) return base;
    return '$base hasta el ${last.day} de ${_months[last.month - 1]}';
  }

  static String _recurrenceBase(Recurrence r) {
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

  /// Al guardar varias tareas dichas en una sola frase.
  static String savedMany(int count, DateTime remindAt, DateTime now) =>
      'Listo. Guardé $count recordatorios para ${when(remindAt, now)}.';

  /// «cuando llegues a Casa» / «cuando salgas del Trabajo».
  static String atPlace(String place, {required bool onArrive}) =>
      onArrive ? 'cuando llegues a $place' : 'cuando salgas de $place';

  static String savedAtPlace(String where, {required bool needsPermission}) =>
      needsPermission
      ? 'Listo, te aviso $where. Para avisarte con la app cerrada, permite '
            'la ubicación todo el tiempo en Ajustes, Lugares.'
      : 'Listo, te aviso $where.';

  static String unknownPlace(String place) =>
      'No tengo guardado «$place». Guárdalo en Ajustes, Lugares, '
      'y vuelve a pedírmelo.';

  // --- Compartir -------------------------------------------------------------

  static const shareNeedsAccount =
      'Para compartir, inicia sesión con Google en Ajustes, Cuenta.';

  static String unknownContact(String name) =>
      'No tengo a «$name» en tus contactos. Agrégalo en Compartir, '
      'Contactos.';

  static String sendTo(String name) => 'Le envío a $name: ';

  static String sentTo(String name) =>
      'Listo, se lo envié a $name. Te aviso cuando lo haga.';

  static const shareFailed =
      'No pude enviarlo. Revisa tu conexión e inténtalo de nuevo.';

  static String listNotFound(String name) =>
      'No encontré la lista «$name». Créala en Compartir, Listas.';

  static String addedToList(List<String> items, String list) =>
      'Listo, agregué ${_joinList([for (final i in items) i.toLowerCase()])} '
      'a la lista $list.';

  static String listContents(String list, List<String> items) => items.isEmpty
      ? 'La lista $list está vacía.'
      : 'En la lista $list tienes: '
            '${_joinList([for (final i in items) i.toLowerCase()])}.';

  /// Título del aviso previo a un evento sin tarea propia.
  static String upcoming(String eventTitle) => 'Se acerca: $eventTitle';

  /// Antecede la confirmación cuando la frase traía varias tareas.
  static String severalTasks(int count) => 'Son $count recordatorios: ';

  /// Respuesta a "¿qué tengo hoy?". [events]: lo del calendario del teléfono
  /// en el mismo rango. [short]: modo conducción (menos detalles).
  static String agenda({
    required List<Reminder> reminders,
    required DateTime from,
    required bool isWeek,
    required DateTime now,
    List<CalendarEvent> events = const [],
    bool short = false,
  }) {
    final label = isWeek
        ? (from.isBefore(now.startOfWeek.addDays(7))
              ? 'esta semana'
              : 'la próxima semana')
        : day(from, now);
    final calendar = events.isEmpty
        ? ''
        : ' ${calendarSummary(events, now, withDay: isWeek, short: short)}';
    if (reminders.isEmpty) {
      return events.isEmpty
          ? 'No tienes pendientes para $label.'
          : 'No tienes pendientes para $label.$calendar';
    }
    final limit = short ? 3 : 5;
    final items = reminders.take(limit).map((r) {
      final at = isWeek ? when(r.dueAt, now) : time(r.dueAt);
      return '${_inSentence(r.title)} $at';
    }).toList();
    final count = reminders.length;
    final intro = count == 1
        ? 'Para $label tienes 1 pendiente'
        : 'Para $label tienes $count pendientes';
    final more = count > limit ? ', entre otros' : '';
    return '${_capitalize(intro)}: ${_joinList(items)}$more.$calendar';
  }

  /// "En tu calendario: reunión con Ana a las 3 de la tarde."
  static String calendarSummary(
    List<CalendarEvent> events,
    DateTime now, {
    bool withDay = false,
    bool short = false,
  }) {
    final limit = short ? 2 : 4;
    final parts = events.take(limit).map((e) {
      final at = e.allDay
          ? (withDay ? day(e.start, now) : 'todo el día')
          : (withDay ? when(e.start, now) : time(e.start));
      return '${_inSentence(e.title)} $at';
    }).toList();
    final more = events.length > limit ? ', entre otros' : '';
    return 'En tu calendario: ${_joinList(parts)}$more.';
  }

  /// "Buenos días", "Buenas tardes" o "Buenas noches".
  static String greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Buenos días',
    < 19 => 'Buenas tardes',
    _ => 'Buenas noches',
  };

  /// Resumen hablado del día: lo de hoy, lo vencido, el calendario y lo que
  /// se acerca.
  static String briefing({
    required DateTime now,
    required List<(String title, DateTime at)> today,
    required int overdue,
    required List<CalendarEvent> events,
    required List<(String title, DateTime at)> soon,
    bool short = false,
  }) {
    final parts = <String>['${greeting(now)}.'];
    if (today.isEmpty) {
      parts.add('Hoy no tienes pendientes.');
    } else {
      final limit = short ? 3 : 5;
      final items = today
          .take(limit)
          .map((i) => '${_inSentence(i.$1)} ${time(i.$2)}')
          .toList();
      final intro = today.length == 1
          ? 'Hoy tienes 1 pendiente'
          : 'Hoy tienes ${today.length} pendientes';
      final more = today.length > limit ? ', entre otros' : '';
      parts.add('$intro: ${_joinList(items)}$more.');
    }
    if (overdue > 0) {
      parts.add(
        overdue == 1
            ? 'Además, quedó 1 pendiente de días anteriores.'
            : 'Además, quedaron $overdue pendientes de días anteriores.',
      );
    }
    if (events.isNotEmpty) {
      parts.add(calendarSummary(events, now, short: short));
    }
    if (soon.isNotEmpty && !short) {
      final items = soon
          .take(3)
          .map((i) => '${_inSentence(i.$1)} ${day(i.$2, now)}')
          .toList();
      parts.add('Se acerca: ${_joinList(items)}.');
    }
    if (today.isEmpty && events.isEmpty && overdue == 0) {
      parts.add('¡Que tengas un buen día!');
    }
    return parts.join(' ');
  }

  /// Frases para pedir el resumen («buenos días, Viernes», «¿cómo está mi
  /// día?»).
  static const briefingTitle = 'Tu día';

  // --- Modo conducción (respuestas cortas) -----------------------------------

  static String confirmationShort({
    required String title,
    required DateTime due,
    required DateTime now,
  }) => '$title, ${when(due, now)}. ¿Sí?';

  static String savedShort(DateTime remindAt, DateTime now) =>
      'Listo, ${when(remindAt, now)}.';

  // --- Listas: responsables --------------------------------------------------

  static String addedToListFor(
    List<String> items,
    String list,
    String assignee,
  ) =>
      'Listo, agregué ${_joinList([for (final i in items) i.toLowerCase()])} '
      'a la lista $list, para $assignee.';

  /// Lo pendiente de una lista con quién lo tiene asignado.
  static String listContentsWithOwners(
    String list,
    List<(String text, String? owner)> items,
  ) {
    if (items.isEmpty) return 'La lista $list está vacía.';
    final parts = [
      for (final (text, owner) in items)
        owner == null ? text.toLowerCase() : '${text.toLowerCase()}, $owner',
    ];
    return 'En la lista $list tienes: ${parts.join('; ')}.';
  }

  static String listMine(String list, List<String> items) => items.isEmpty
      ? 'En la lista $list no tienes nada asignado.'
      : 'En la lista $list te toca: '
            '${_joinList([for (final i in items) i.toLowerCase()])}.';

  // --- Cumpleaños ------------------------------------------------------------

  static String birthdayTitle(String name) => 'Cumpleaños de $name';

  static String birthdaySoonTitle(String name) =>
      'Se acerca el cumpleaños de $name';

  static List<String> _dayNames(Set<int> weekdays) =>
      (weekdays.toList()..sort()).map((d) => _weekdays[d - 1]).toList();

  static const morningSummaryTitle = 'Buenos días ☀️';

  /// "Hoy tienes 3 pendientes: entregar el informe a las 8 de la mañana…"
  static String morningSummary(
    List<(String title, DateTime at)> items, {
    List<CalendarEvent> events = const [],
    DateTime? now,
  }) {
    final calendar = events.isEmpty
        ? ''
        : ' ${calendarSummary(events, now ?? events.first.start)}';
    if (items.isEmpty) return 'Hoy no tienes pendientes.$calendar';
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
    return '$intro: ${_joinList(parts)}$more.$calendar';
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
