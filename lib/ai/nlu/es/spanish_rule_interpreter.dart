// Las expresiones regulares se arman por partes; los fragmentos van pegados a
// propósito (sin espacios entre cadenas).
// ignore_for_file: missing_whitespace_between_adjacent_strings
// ignore_for_file: unnecessary_raw_strings

import 'package:viernes/ai/nlu/es/category_classifier.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/ai/nlu/reminder_interpreter.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Intérprete de reglas para español (énfasis en el español de Colombia).
///
/// Estrategia: se buscan expresiones (fecha, hora, repetición…) sobre el texto
/// normalizado, se "reclaman" sus posiciones y lo que sobra, una vez quitadas
/// las muletillas ("recuérdame", "tengo que"…), es el título de la tarea.
class SpanishRuleInterpreter implements ReminderInterpreter {
  const SpanishRuleInterpreter();

  static const version = 'rules-es-1.0';

  @override
  Future<Interpretation> interpret(
    String text,
    DateTime now, {
    MissingSlot? expecting,
  }) async => parse(text, now, expecting: expecting);

  /// Versión síncrona, útil en pruebas y para el intérprete híbrido.
  Interpretation parse(String text, DateTime now, {MissingSlot? expecting}) =>
      _Parser(text, now, expecting).run();

  /// Limpia muletillas del inicio y del final de un texto libre.
  static String cleanTitle(String text) => _Parser.cleanTitle(text);
}

RegExp _re(String pattern) => RegExp(
  pattern
      .replaceAll('MINNUM', SpanishText.minuteNumber)
      .replaceAll('NUM', SpanishText.number)
      .replaceAll('WD', SpanishText.weekdayPattern)
      .replaceAll('MONTH', SpanishText.monthPattern),
);

// --- Patrones -------------------------------------------------------------

final RegExp _wakeWord = _re(
  r'^[\s¿¡]*(?:(?:oye|hola|ok|okey)\s+)?viernes\b[\s,.:;!¡]*',
);

final RegExp _query = _re(
  r'^[\s¿¡]*(?:(?:oye|hola)\s+)?(?:viernes\b[\s,]*)?(?:(?:que|cuales?)\s+'
  r'(?:tengo|hay|me toca|son mis|es mi|pendientes)|(?:dime|leeme|lee|'
  r'muestrame|cuentame|repasa|revisa)\s+(?:que tengo|mis|mi|lo que)|'
  r'(?:mi|mis)\s+(?:agenda|pendientes|recordatorios)\b)',
);
final RegExp _queryWeek = _re(r'\b(?:esta semana|la semana|semana)\b');

final RegExp _lead = _re(
  r'\b(?:(?:avisame|recuerdamelo|recuerdame|avisarme|recordarmelo|con)\s+)?'
  r'(?:(?<n>NUM)\s+(?<u>minutos?|mins?|horas?|dias?)|(?<half>media hora)|'
  r'(?<quarter>un cuarto de hora))\s+(?:antes|de anticipacion|de antelacion)'
  r'\b|\b(?:(?:avisame|recuerdamelo|recuerdame)\s+)?(?<daybefore>el dia '
  r'anterior|la noche anterior|un dia antes)\b',
);

final RegExp _recWeekdays = _re(
  r'\b(?:del? lunes al? viernes|entre semana|(?:todos los |los )?dias habiles|'
  r'cada dia habil)\b',
);
final RegExp _recFortnight = _re(r'\bcada\s+(?:quince|15)\s+dias\b');
final RegExp _recEveryNDays = _re(r'\bcada\s+(?<n>NUM)\s+dias\b');
final RegExp _recDaily = _re(
  r'\b(?:todos los (?:santos )?dias|cada dia|diariamente|a diario|'
  r'todas las (?<per>mananas|tardes|noches))\b',
);
final RegExp _recWeekDays = _re(
  r'\b(?:todos los|todas los|cada|los)\s+(?<days>WD(?:\s*(?:,|y|e)\s*'
  r'(?:los\s+)?WD)*)\b',
);
final RegExp _recEveryNWeeks = _re(r'\bcada\s+(?<n>NUM)\s+semanas\b');
final RegExp _recWeekly = _re(
  r'\b(?:cada semana|semanalmente|todas las semanas)\b',
);
final RegExp _recMonthDay = _re(
  r'\b(?:el\s+)?(?:dia\s+)?(?<d>NUM)\s+de\s+(?:cada|todos los)\s+mes(?:es)?\b',
);
final RegExp _recMonthly = _re(
  r'\b(?:cada mes|mensualmente|todos los meses)\b',
);
final RegExp _recYearly = _re(r'\b(?:cada ano|anualmente|todos los anos)\b');

/// «Por 30 días», «durante dos semanas», «los próximos 10 días».
final RegExp _span = _re(
  r'\b(?:por|durante|(?:los|las)\s+proxim[oa]s)\s+(?<n>NUM)\s+'
  r'(?<u>dias|semanas|meses)\b',
);

/// «Del 5 al 10», «desde el 5 hasta el 10 de noviembre».
final RegExp _dateRange = _re(
  r'\b(?:del|desde el)\s+(?:dia\s+)?(?<a>NUM)(?:\s+de\s+(?<ma>MONTH))?\s+'
  r'(?:al|hasta el)\s+(?:dia\s+)?(?<b>NUM)(?:\s+de\s+(?<mb>MONTH))?\b',
);

/// Último día de una repetición: «todos los días hasta el 20».
final RegExp _untilDate = _re(
  r'\b(?:hasta el|hasta)\s+(?:dia\s+)?(?<d>NUM)(?:\s+de\s+(?<m>MONTH))?\b',
);

/// Relleno que no forma parte de la tarea: «esos días», «tienes que estarme
/// recordando», «así que», «entonces».
final RegExp _noise = _re(
  r'\b(?:(?:todos\s+)?(?:esos|estos|esas|estas|aquellos)\s+dias|'
  r'(?:me\s+)?(?:tienes|tenes|vas) que (?:estar(?:me)?\s+)?'
  r'(?:recordando(?:me)?|recordarme(?:lo)?|avisarme|avisando(?:me)?)|'
  r'(?:estar(?:me)?|seguir(?:me)?)\s+(?:recordando|avisando)(?:me)?|'
  r'me (?:lo )?recuerdas|asi que|entonces|o sea)\b',
);

/// «Activa una alarma», «despiértame»: si no hay más título, se llama así.
final RegExp _alarm = _re(
  r'^[\s¿¡]*(?:(?:oye\s+)?viernes[\s,]*)?(?:por favor\s+)?(?:(?<alarm>'
  r'(?:activa|activame|pon|ponme|programa|programame|crea|creame|'
  r'configura)\s+(?:una|la|un)\s+(?:alarma|despertador))|(?<wake>'
  r'despiertame|levantame))\b',
);

final RegExp _relative = _re(
  r'\b(?:en|dentro de)\s+(?:(?<n>NUM)\s+(?<u>minutos?|mins?|horas?)'
  r'(?:\s+y\s+(?<plushalf>media))?|(?<half>media hora)|'
  r'(?<quarter>un cuarto de hora)|(?<rato>un rato|un ratico|un ratito))\b',
);

const _ampm = r'(?<ap>a\.?\s?m\.?|p\.?\s?m\.?)';
const _period = r'(?<per>manana|tarde|noche|madrugada)';
const _minutes =
    r'(?:\s*(?::|\.|h)\s*(?<mm>\d{2})|\s+y\s+(?<my>cuarto|media|MINNUM)|'
    r'\s+menos\s+(?<mn>cuarto|MINNUM))?';

final RegExp _timeWithPrefix = _re(
  r'\b(?<pre>antes de las?|a mas tardar a las?|maximo a las?|hasta las?|'
  r'para las?|a eso de las?|como a las?|tipo|sobre las?|a las?)\s+'
  r'(?<h>NUM)'
  '$_minutes'
  r'(?:\s*'
  '$_ampm'
  r'|\s+(?:de|en|por)\s+la\s+'
  '$_period'
  r')?\b',
);
final RegExp _timeAmPm = _re(
  r'\b(?<h>\d{1,2})(?:\s*:\s*(?<mm>\d{2}))?\s*'
  '$_ampm'
  r'(?=[\s,.;!?]|$)',
);
final RegExp _timeClock = _re(r'\b(?<h>\d{1,2}):(?<mm>\d{2})\b');
final RegExp _timeWithPeriod = _re(
  r'\b(?<h>NUM)'
  '$_minutes'
  r'\s+(?:de|en|por)\s+la\s+'
  '$_period'
  r'\b',
);
final RegExp _timeNoon = _re(
  r'\b(?:(?<pre>antes del?|a mas tardar al?|para el|hasta el)\s+)?'
  r'(?:al\s+|a\s+|el\s+)?(?<w>mediodia|medio dia|medianoche|media noche)\b',
);
final RegExp _timeBare = _re(
  r'^\s*(?:a\s+)?(?:las?\s+)?(?<h>NUM)'
  '$_minutes'
  r'(?:\s*'
  '$_ampm'
  r'|\s+(?:de|en|por)\s+la\s+'
  '$_period'
  r')?\s*[.!]?\s*$',
);

final RegExp _dayPeriod = _re(
  r'\b(?<pre>esta|en la|por la|a la|de la|en las|por las|a las)\s+'
  r'(?<per>mananita|manana|tardecita|tarde|nochecita|noche|madrugada)s?\b',
);
final RegExp _early = _re(r'\b(?:bien\s+)?(?:temprano|tempranito)\b');

final RegExp _dayAfterTomorrow = _re(r'\bpasado\s+manana\b');
final RegExp _tomorrow = _re(r'\bmanana\b');
final RegExp _today = _re(r'\bhoy(?:\s+mismo)?\b');
final RegExp _weekday = _re(
  r'\b(?:(?<el>el|este|esta)\s+)?(?:(?<prox>proximo|proxima)\s+)?(?<wd>WD)'
  r'(?:\s+(?<next>proximo|que viene)|\s+(?<nextweek>de la (?:proxima|otra) '
  r'semana|de la semana que viene))?\b',
);
final RegExp _nextWeek = _re(
  r'\b(?:la\s+)?(?:proxima semana|semana que viene|otra semana)\b',
);
final RegExp _inDays = _re(
  r'\b(?:en|dentro de)\s+(?<n>NUM)\s+(?<u>dias?|semanas?|mes(?:es)?)\b',
);
final RegExp _dayMonth = _re(
  r'\b(?:el\s+)?(?:dia\s+)?(?<d>NUM)\s+de\s+(?<m>MONTH)'
  r'(?:\s+(?:de|del)\s+(?<y>\d{4}))?\b',
);
final RegExp _numericDate = _re(
  r'\b(?<d>\d{1,2})[/-](?<m>\d{1,2})(?:[/-](?<y>\d{2,4}))?\b',
);
final RegExp _dayWord = _re(r'\b(?:el\s+)?dia\s+(?<d>NUM)\b');
final RegExp _dayNumber = _re(r'\bel\s+(?<d>\d{1,2}|primero)\b');
final RegExp _endOfMonth = _re(
  r'\b(?:a\s+)?(?:fin|final|finales)\s+del?\s+mes\b',
);

/// "Antes del viernes", "a más tardar el 20": la fecha es un límite.
final RegExp _beforeDate = RegExp(
  r'\b(?:antes de(?:l| la| las)?|a mas tardar(?: el| la)?|hasta(?: el)?|'
  r'maximo(?: el)?)\s*$',
);

final RegExp _priorityLow = _re(
  r'\b(?:no es urgente|sin prisa|sin afan|cuando pueda|cuando puedas|'
  r'prioridad baja|no es importante)\b',
);
final RegExp _priorityUrgent = _re(
  r'\b(?:es\s+)?(?:(?:muy|super)\s+)?(?:urgente|urgentisimo)\b|'
  r'\b(?:es\s+)?(?:muy|super)\s+importante\b|'
  r'\bprioridad (?:maxima|urgente)\b|\bde urgencia\b',
);
final RegExp _priorityHigh = _re(
  r'\b(?:es\s+)?importante\b|\bprioridad alta\b',
);

const _leadingFillers =
    'oye viernes|viernes|oye|hola|por favor|porfavor|porfa|'
    'hazme acuerdo de que|hazme acuerdo de|hazme acuerdo que|hazme acuerdo|'
    'hazme acordar de|hazme acordar que|hazme acordar|hazme recordar que|'
    'hazme recordar|hazme el favor de|hazme el favor|hazme un recordatorio|'
    'activa una alarma para|activa una alarma de|activa una alarma|'
    'activame una alarma para|activame una alarma|pon una alarma para|'
    'pon una alarma|ponme una alarma para|ponme una alarma|'
    'programa una alarma para|programa una alarma|crea una alarma para|'
    'crea una alarma|despiertame|levantame|me recuerdas que|'
    'quiero que me recuerdes que|quiero que me recuerdes|'
    'necesito que me recuerdes que|necesito que me recuerdes|'
    'recuerdame por favor que|recuerdame por favor|'
    'recuerdame que|recuerdame de|recuerdame|recordarme que|recordarme|'
    'acuerdame que|acuerdame de|acuerdame|avisame que|avisame de|'
    'avisame para|avisame|recuerdalo|anota que|anota|apunta que|apunta|'
    'agendame|agenda|agrega|crea un recordatorio para|'
    'crea un recordatorio de|crea un recordatorio|'
    'ponme un recordatorio para|ponme un recordatorio|'
    'pon un recordatorio para|pon un recordatorio|nuevo recordatorio|'
    'no me dejes olvidar que|no me dejes olvidar|no olvides que|'
    'no olvides|que no se me olvide|no se me puede olvidar|'
    'tenemos que|tengo que|tengo|debo de|debo|necesito|hay que|me toca|'
    'toca|voy a|tenemos|'
    'que|de|para|y|e|a|el|la|los|las|un|una|unos|unas|es|son';
final RegExp _leading = RegExp(
  '^[\\s,.;:!¡?¿-]*(?:$_leadingFillers)\\b[\\s,.;:!?-]*',
);
final RegExp _trailing = RegExp(
  r'[\s,.;:!?¡¿-]*\b(?:por favor|porfa|gracias|y|que|de|del|a|al|para|el|la|'
  r'en|con|por|es|tengo|o sea|entonces|asi que|pues|ok|vale|listo|bueno)'
  r'[\s,.;:!?-]*$',
);
final RegExp _trailingPunctuation = RegExp(r'[\s,.;:!?¡¿-]+$');
final RegExp _leadingPunctuation = RegExp(r'^[\s,.;:!?¡¿-]+');

class _Parser {
  _Parser(this.original, this.now, this.expecting)
    : folded = SpanishText.fold(original);

  final String original;
  final String folded;
  final DateTime now;
  final MissingSlot? expecting;

  final _claimed = <(int, int)>[];

  DateTime? date;
  DayTime? time;
  bool ambiguousHour = false;
  DayPeriod? dayPeriod;
  DateTime? exactDue;
  bool isDeadline = false;
  Duration? leadTime;
  Recurrence recurrence = Recurrence.none;
  ReminderPriority? priority;

  /// «Por 30 días»: cuánto dura la repetición desde el primer día.
  (int, String)? _spanLength;

  /// «Del 5 al 10» / «hasta el 20»: último día de la repetición.
  DateTime? _lastDay;

  DateTime get today => now.startOfDay;

  Interpretation run() {
    if (folded.trim().isEmpty) return _result(VoiceIntent.unknown, '');

    _claimFirst(_wakeWord);

    if (_query.hasMatch(folded)) return _agendaQuery();

    final alarm = _alarm.firstMatch(folded);
    _free(_noise).toList().forEach(_claim);
    _extractLeadTime();
    _extractSpan();
    _extractRecurrence();
    _extractUntil();
    _extractRelative();
    _extractTime();
    _extractDayPeriod();
    _extractDate();
    _extractPriority();
    _applySpan();

    var title = _buildTitle();
    if (title.isEmpty && alarm != null) {
      title = alarm.namedGroup('wake') != null ? 'Despertar' : 'Alarma';
    }
    final reminder = ParsedReminder(
      title: title,
      date: date,
      time: time,
      dayPeriod: dayPeriod,
      exactDue: exactDue,
      isDeadline: isDeadline,
      leadTime: leadTime,
      recurrence: recurrence,
      priority: priority,
      category: title.isEmpty
          ? ReminderCategory.other
          : CategoryClassifier.classify(title),
      ambiguousHour: ambiguousHour,
    );
    final intent = title.isEmpty && !reminder.hasAnySlot
        ? VoiceIntent.unknown
        : VoiceIntent.createReminder;
    return _result(intent, title, reminder: reminder);
  }

  // --- Reclamo de posiciones ---------------------------------------------

  bool _isFree(int start, int end) =>
      end > start && _claimed.every((c) => end <= c.$1 || start >= c.$2);

  void _claim(Match m) => _claimed.add((m.start, m.end));

  Iterable<RegExpMatch> _free(RegExp re) =>
      re.allMatches(folded).where((m) => _isFree(m.start, m.end));

  RegExpMatch? _claimFirst(RegExp re) {
    final match = _free(re).firstOrNull;
    if (match != null) _claim(match);
    return match;
  }

  // --- Consultas ---------------------------------------------------------

  Interpretation _agendaQuery() {
    final nextWeek = _nextWeek.hasMatch(folded);
    _extractDate();
    final AgendaQuery query;
    if (nextWeek) {
      final monday = today.startOfWeek.addDays(7);
      query = AgendaQuery(from: monday, to: monday.addDays(7), isWeek: true);
    } else if (date != null) {
      query = AgendaQuery(from: date!, to: date!.addDays(1));
    } else if (_queryWeek.hasMatch(folded)) {
      query = AgendaQuery(
        from: today,
        to: today.startOfWeek.addDays(7),
        isWeek: true,
      );
    } else {
      query = AgendaQuery(from: today, to: today.addDays(1));
    }
    return Interpretation(
      text: original,
      intent: VoiceIntent.queryAgenda,
      confidence: 0.9,
      interpreterVersion: SpanishRuleInterpreter.version,
      agenda: query,
    );
  }

  // --- Extractores ---------------------------------------------------------

  void _extractLeadTime() {
    final m = _claimFirst(_lead);
    if (m == null) return;
    if (m.namedGroup('daybefore') != null) {
      leadTime = const Duration(days: 1);
    } else if (m.namedGroup('half') != null) {
      leadTime = const Duration(minutes: 30);
    } else if (m.namedGroup('quarter') != null) {
      leadTime = const Duration(minutes: 15);
    } else {
      final n = SpanishText.parseNumber(m.namedGroup('n')) ?? 0;
      leadTime = _unitDuration(n, m.namedGroup('u')!);
    }
  }

  void _extractRecurrence() {
    if (_claimFirst(_recWeekdays) != null) {
      recurrence = Recurrence.weekdaysOnly;
      return;
    }
    if (_claimFirst(_recFortnight) != null) {
      recurrence = Recurrence.weekly(const {}, interval: 2);
      return;
    }
    final everyN = _claimFirst(_recEveryNDays);
    if (everyN != null) {
      final n = SpanishText.parseNumber(everyN.namedGroup('n')) ?? 1;
      recurrence = Recurrence(
        frequency: RecurrenceFrequency.daily,
        interval: n.clamp(1, 365),
      );
      return;
    }
    final daily = _claimFirst(_recDaily);
    if (daily != null) {
      recurrence = Recurrence.daily;
      final per = daily.namedGroup('per');
      if (per != null) dayPeriod = _periodFromWord(per);
      return;
    }
    final days = _claimFirst(_recWeekDays);
    if (days != null) {
      final set = RegExp(SpanishText.weekdayPattern)
          .allMatches(days.namedGroup('days')!)
          .map((d) => SpanishText.weekdays[d.group(0)]!)
          .toSet();
      recurrence = Recurrence.weekly(set);
      return;
    }
    final everyNWeeks = _claimFirst(_recEveryNWeeks);
    if (everyNWeeks != null) {
      final n = SpanishText.parseNumber(everyNWeeks.namedGroup('n')) ?? 1;
      recurrence = Recurrence.weekly(const {}, interval: n.clamp(1, 52));
      return;
    }
    if (_claimFirst(_recWeekly) != null) {
      recurrence = Recurrence.weekly(const {});
      return;
    }
    final monthDay = _claimFirst(_recMonthDay);
    if (monthDay != null) {
      final d = SpanishText.parseNumber(monthDay.namedGroup('d'));
      if (d != null && d >= 1 && d <= 31) {
        recurrence = Recurrence.monthly(d);
        date = _nextDayOfMonth(d);
        return;
      }
    }
    if (_claimFirst(_recMonthly) != null) {
      recurrence = const Recurrence(frequency: RecurrenceFrequency.monthly);
      return;
    }
    if (_claimFirst(_recYearly) != null) {
      recurrence = const Recurrence(frequency: RecurrenceFrequency.yearly);
    }
  }

  /// «Por 30 días» y «del 5 al 10». La fecha de inicio de un rango manda
  /// sobre las demás.
  void _extractSpan() {
    final range = _claimFirst(_dateRange);
    if (range != null) {
      final a = SpanishText.parseNumber(range.namedGroup('a'));
      final b = SpanishText.parseNumber(range.namedGroup('b'));
      final mb = SpanishText.months[range.namedGroup('mb') ?? ''];
      final ma = SpanishText.months[range.namedGroup('ma') ?? ''] ?? mb;
      if (a != null && b != null && a >= 1 && a <= 31 && b >= 1 && b <= 31) {
        final (start, end) = _resolveRange(a, b, ma, mb);
        if (start != null && end != null && !end.isBefore(start)) {
          date = start;
          _lastDay = end;
        }
      }
    }
    // Se reclaman todas: la gente lo repite («por 30 días … por 30 días»).
    for (final m in _free(_span).toList()) {
      _claim(m);
      final n = SpanishText.parseNumber(m.namedGroup('n'));
      if (n != null && n >= 1) _spanLength ??= (n, m.namedGroup('u')!);
    }
  }

  /// Primer y último día de «del [a] al [b]». Sin mes, es el próximo rango
  /// que todavía no termina (si ya empezó, desde hoy).
  (DateTime?, DateTime?) _resolveRange(int a, int b, int? ma, int? mb) {
    if (ma != null || mb != null) {
      final start = _dateFrom(a, ma ?? mb!, null);
      if (start == null) return (null, null);
      var end = DateTime(start.year, mb ?? start.month, b);
      if (end.isBefore(start)) end = DateTime(end.year + 1, end.month, b);
      return (start, end);
    }
    for (var offset = 0; offset < 13; offset++) {
      final month = DateTime(today.year, today.month + offset);
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      if (a > lastDay) continue;
      final start = DateTime(month.year, month.month, a);
      // «Del 28 al 3»: termina el mes siguiente.
      final end = b >= a
          ? DateTime(month.year, month.month, b.clamp(1, lastDay))
          : DateTime(month.year, month.month + 1, b);
      if (end.isBefore(today)) continue;
      return (start.isBefore(today) ? today : start, end);
    }
    return (null, null);
  }

  void _extractUntil() {
    if (!recurrence.repeats && _spanLength == null) return;
    final m = _claimFirst(_untilDate);
    if (m == null) return;
    final d = SpanishText.parseNumber(m.namedGroup('d'));
    final month = SpanishText.months[m.namedGroup('m') ?? ''];
    if (d == null || d < 1 || d > 31) return;
    _lastDay = month == null ? _nextDayOfMonth(d) : _dateFrom(d, month, null);
  }

  /// Convierte «por 30 días» y «del 5 al 10» en una repetición con último
  /// día. Si no se dijo cada cuánto, es todos los días.
  void _applySpan() {
    var last = _lastDay;
    final span = _spanLength;
    if (last == null && span != null) {
      final start = date ?? today;
      final (n, unit) = span;
      last = switch (unit) {
        'semanas' => start.addDays(n * 7 - 1),
        'meses' => start.addMonthsClamped(n).addDays(-1),
        _ => start.addDays(n - 1),
      };
    }
    if (last == null) return;
    if (!recurrence.repeats) recurrence = Recurrence.daily;
    recurrence = recurrence.withUntil(last);
  }

  void _extractRelative() {
    final m = _claimFirst(_relative);
    if (m == null) return;
    Duration delta;
    if (m.namedGroup('half') != null) {
      delta = const Duration(minutes: 30);
    } else if (m.namedGroup('quarter') != null) {
      delta = const Duration(minutes: 15);
    } else if (m.namedGroup('rato') != null) {
      delta = const Duration(minutes: 30);
    } else {
      final n = SpanishText.parseNumber(m.namedGroup('n')) ?? 0;
      delta = _unitDuration(n, m.namedGroup('u')!);
      if (m.namedGroup('plushalf') != null) {
        delta += const Duration(minutes: 30);
      }
    }
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    exactDue = base.add(delta);
  }

  void _extractTime() {
    for (final re in [
      _timeWithPrefix,
      _timeAmPm,
      _timeWithPeriod,
      _timeClock,
    ]) {
      for (final m in _free(re)) {
        final parsed = _timeFromMatch(m);
        if (parsed == null) continue;
        _claim(m);
        time = parsed;
        final pre = _group(m, 'pre');
        if (pre != null &&
            (pre.startsWith('antes') ||
                pre.startsWith('a mas tardar') ||
                pre.startsWith('maximo') ||
                pre.startsWith('hasta'))) {
          isDeadline = true;
        }
        return;
      }
    }

    final noon = _claimFirst(_timeNoon);
    if (noon != null) {
      final word = noon.namedGroup('w')!;
      time = word.startsWith('medio')
          ? const DayTime(12, 0)
          : const DayTime(23, 59);
      final pre = noon.namedGroup('pre');
      isDeadline = pre != null && !pre.startsWith('para');
      return;
    }

    if (expecting == MissingSlot.time) {
      final bare = _free(_timeBare).firstOrNull;
      final parsed = bare == null ? null : _timeFromMatch(bare);
      if (parsed != null) {
        _claim(bare!);
        time = parsed;
      }
    }
  }

  DayTime? _timeFromMatch(RegExpMatch m) {
    var hour = SpanishText.parseNumber(m.namedGroup('h'));
    if (hour == null || hour > 24) return null;
    if (hour == 24) hour = 0;

    var minute = int.tryParse(_group(m, 'mm') ?? '') ?? 0;
    final my = _group(m, 'my');
    final mn = _group(m, 'mn');
    if (my != null) {
      minute = switch (my) {
        'cuarto' => 15,
        'media' => 30,
        _ => SpanishText.parseNumber(my) ?? 0,
      };
    } else if (mn != null) {
      final less = mn == 'cuarto' ? 15 : SpanishText.parseNumber(mn) ?? 0;
      if (less <= 0 || less >= 60) return null;
      hour = (hour - 1) % 24;
      minute = 60 - less;
    }
    if (minute >= 60) return null;

    final ap = _group(m, 'ap')?.replaceAll(RegExp(r'[\s.]'), '');
    final per = _group(m, 'per');
    if (ap == 'am') {
      if (hour > 12) return null;
      if (hour == 12) hour = 0;
    } else if (ap == 'pm') {
      if (hour > 12) return null;
      if (hour < 12) hour += 12;
    } else if (per != null) {
      hour = _hourWithPeriod(hour, _periodFromWord(per));
    } else if (hour >= 1 && hour <= 6) {
      // "A las 2 tengo reunión": casi nadie agenda a las 2 de la madrugada.
      hour += 12;
    } else if (hour >= 7 && hour <= 11) {
      ambiguousHour = true;
    }
    return DayTime(hour % 24, minute);
  }

  /// Algunos grupos con nombre no existen en todos los patrones.
  String? _group(RegExpMatch m, String name) =>
      m.groupNames.contains(name) ? m.namedGroup(name) : null;

  int _hourWithPeriod(int hour, DayPeriod period) => switch (period) {
    DayPeriod.dawn ||
    DayPeriod.early ||
    DayPeriod.morning => hour == 12 ? 0 : hour,
    DayPeriod.noon => 12,
    DayPeriod.afternoon => hour < 12 ? hour + 12 : hour,
    // "12 de la noche" = medianoche; "1 a 4 de la noche" = madrugada.
    DayPeriod.night =>
      hour == 12 ? 0 : (hour >= 5 && hour < 12 ? hour + 12 : hour),
  };

  void _extractDayPeriod() {
    final m = _claimFirst(_dayPeriod);
    if (m != null) {
      final period = _periodFromWord(m.namedGroup('per')!);
      if (m.namedGroup('pre') == 'esta') date ??= today;
      if (time == null) {
        dayPeriod = period;
      } else if (ambiguousHour || time!.hour < 12) {
        // "A las 8 … en la noche": la franja aclara la hora.
        time = DayTime(_hourWithPeriod(time!.hour, period), time!.minute);
        ambiguousHour = false;
      }
      return;
    }
    if (_claimFirst(_early) != null && time == null) {
      dayPeriod = DayPeriod.early;
    }
  }

  /// Reclama una fecha y, si va precedida de "antes de…", la marca como
  /// límite.
  void _claimDate(Match m) {
    _claim(m);
    final before = _beforeDate.firstMatch(folded.substring(0, m.start));
    if (before != null && _isFree(before.start, before.end)) {
      _claimed.add((before.start, before.end));
      isDeadline = true;
    }
  }

  RegExpMatch? _claimFirstDate(RegExp re) {
    final match = _free(re).firstOrNull;
    if (match != null) _claimDate(match);
    return match;
  }

  void _extractDate() {
    if (_claimFirstDate(_dayAfterTomorrow) != null) {
      date = today.addDays(2);
      return;
    }
    if (_claimFirstDate(_tomorrow) != null) {
      date = today.addDays(1);
      return;
    }
    if (_claimFirstDate(_today) != null) {
      date = today;
      return;
    }

    final wd = _claimFirstDate(_weekday);
    if (wd != null) {
      final target = SpanishText.weekdays[wd.namedGroup('wd')]!;
      if (wd.namedGroup('nextweek') != null) {
        date = today.startOfWeek.addDays(7 + target - 1);
        return;
      }
      var ahead = (target - today.weekday + 7) % 7;
      final saysThis = const {'este', 'esta'}.contains(wd.namedGroup('el'));
      if (ahead == 0 && !saysThis) ahead = 7;
      date = today.addDays(ahead);
      return;
    }

    if (_claimFirstDate(_nextWeek) != null) {
      date = today.startOfWeek.addDays(7);
      return;
    }

    final inDays = _claimFirstDate(_inDays);
    if (inDays != null) {
      final n = SpanishText.parseNumber(inDays.namedGroup('n')) ?? 0;
      final unit = inDays.namedGroup('u')!;
      date = unit.startsWith('mes')
          ? today.addMonthsClamped(n)
          : today.addDays(unit.startsWith('semana') ? n * 7 : n);
      return;
    }

    final dayMonth = _free(_dayMonth).firstOrNull;
    if (dayMonth != null) {
      final d = SpanishText.parseNumber(dayMonth.namedGroup('d'));
      final month = SpanishText.months[dayMonth.namedGroup('m')]!;
      final year = int.tryParse(dayMonth.namedGroup('y') ?? '');
      // Si la fecha no existe ("31 de noviembre") se descarta, pero se
      // reclama para que "el 31" no se interprete por separado.
      _claimDate(dayMonth);
      date = d == null ? null : _dateFrom(d, month, year);
      return;
    }

    final numeric = _free(_numericDate).firstOrNull;
    if (numeric != null) {
      final d = int.parse(numeric.namedGroup('d')!);
      final month = int.parse(numeric.namedGroup('m')!);
      var year = int.tryParse(numeric.namedGroup('y') ?? '');
      if (year != null && year < 100) year += 2000;
      final resolved = month >= 1 && month <= 12
          ? _dateFrom(d, month, year)
          : null;
      if (resolved != null) {
        _claimDate(numeric);
        date = resolved;
        return;
      }
    }

    for (final re in [_dayWord, _dayNumber]) {
      final m = _free(re).firstOrNull;
      if (m == null) continue;
      final d = SpanishText.parseNumber(m.namedGroup('d'));
      if (d == null || d < 1 || d > 31) continue;
      _claimDate(m);
      date = _nextDayOfMonth(d);
      return;
    }

    if (_claimFirstDate(_endOfMonth) != null) {
      date = DateTime(today.year, today.month + 1, 0);
    }
  }

  void _extractPriority() {
    if (_claimFirst(_priorityLow) != null) {
      priority = ReminderPriority.low;
    } else if (_claimFirst(_priorityUrgent) != null) {
      priority = ReminderPriority.urgent;
    } else if (_claimFirst(_priorityHigh) != null) {
      priority = ReminderPriority.high;
    }
  }

  // --- Fechas --------------------------------------------------------------

  /// Próximo día [day] del mes (este mes si aún no pasó).
  DateTime _nextDayOfMonth(int day) {
    for (var offset = 0; offset < 13; offset++) {
      final first = DateTime(today.year, today.month + offset);
      final lastDay = DateTime(first.year, first.month + 1, 0).day;
      if (day > lastDay) continue;
      final candidate = DateTime(first.year, first.month, day);
      if (!candidate.isBefore(today)) return candidate;
    }
    return today;
  }

  DateTime? _dateFrom(int day, int month, int? year) {
    final y = year ?? today.year;
    final lastDay = DateTime(y, month + 1, 0).day;
    if (day < 1 || day > lastDay) return null;
    final candidate = DateTime(y, month, day);
    if (year == null && candidate.isBefore(today)) {
      return _dateFrom(day, month, y + 1);
    }
    return candidate;
  }

  Duration _unitDuration(int n, String unit) {
    if (unit.startsWith('min')) return Duration(minutes: n);
    if (unit.startsWith('hora')) return Duration(hours: n);
    return Duration(days: n);
  }

  DayPeriod _periodFromWord(String word) {
    if (word.startsWith('madrugada')) return DayPeriod.dawn;
    if (word.startsWith('manana')) return DayPeriod.morning;
    if (word.startsWith('tarde')) return DayPeriod.afternoon;
    return DayPeriod.night;
  }

  // --- Título --------------------------------------------------------------

  String _buildTitle() {
    final chars = original.split('');
    for (final (start, end) in _claimed) {
      for (var i = start; i < end && i < chars.length; i++) {
        chars[i] = ' ';
      }
    }
    return cleanTitle(chars.join());
  }

  static String cleanTitle(String input) {
    var text = input;
    for (var i = 0; i < 12; i++) {
      final before = text;
      final lead = _leading.firstMatch(SpanishText.fold(text));
      if (lead != null) text = text.substring(lead.end);
      final trail = _trailing.firstMatch(SpanishText.fold(text));
      if (trail != null) text = text.substring(0, trail.start);
      if (text == before) break;
    }
    text = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(r'([,;:])(?:\s*[,;:.])+'),
          (m) => m.group(1)!,
        )
        .replaceAll(_leadingPunctuation, '')
        .replaceAll(_trailingPunctuation, '')
        .trim();
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  Interpretation _result(
    VoiceIntent intent,
    String title, {
    ParsedReminder reminder = ParsedReminder.empty,
  }) {
    var confidence = 0.4;
    if (title.isNotEmpty) confidence += 0.3;
    if (reminder.resolveDue(now) != null) {
      confidence += 0.3;
    } else if (reminder.hasWhen) {
      confidence += 0.15;
    }
    // Cifras sueltas en el título suelen ser una hora o fecha no entendida.
    if (RegExp(r'\d').hasMatch(title)) confidence -= 0.2;
    if (title.split(' ').length > 12) confidence -= 0.1;
    if (intent == VoiceIntent.unknown) confidence = 0;
    return Interpretation(
      text: original,
      intent: intent,
      reminder: reminder,
      confidence: confidence.clamp(0, 1),
      interpreterVersion: SpanishRuleInterpreter.version,
    );
  }
}
