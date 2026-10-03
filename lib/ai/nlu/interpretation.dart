import 'package:flutter/foundation.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/core/utils/day_time.dart';
import 'package:viernes/features/reminders/domain/entities/recurrence.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';

/// Qué quiere hacer el usuario con la frase.
enum VoiceIntent {
  /// "Mañana a las 8 entregar el informe".
  createReminder,

  /// "¿Qué tengo hoy?".
  queryAgenda,

  /// No se entendió nada útil.
  unknown,
}

/// Dato que falta para poder crear el recordatorio.
enum MissingSlot { title, when, time }

/// Franja del día mencionada sin hora exacta ("en la tarde").
enum DayPeriod {
  dawn(DayTime(6, 0)),
  early(DayTime(7, 0)),
  morning(DayTime(9, 0)),
  noon(DayTime(12, 0)),
  afternoon(DayTime(15, 0)),
  night(DayTime(20, 0));

  const DayPeriod(this.defaultTime);

  /// Hora que se usa cuando solo se dice la franja.
  final DayTime defaultTime;
}

/// Lo que el intérprete extrajo de una frase, por partes.
///
/// Se guarda por componentes (fecha, hora, franja…) y no como una fecha final
/// para poder combinar correcciones: "no, a las 9" cambia solo la hora.
@immutable
class ParsedReminder {
  const ParsedReminder({
    this.title = '',
    this.date,
    this.time,
    this.dayPeriod,
    this.exactDue,
    this.isDeadline = false,
    this.leadTime,
    this.recurrence = Recurrence.none,
    this.priority,
    this.category = ReminderCategory.other,
    this.ambiguousHour = false,
  });

  static const empty = ParsedReminder();

  /// Qué hay que hacer, ya limpio ("Entregar el informe").
  final String title;

  /// Día mencionado, sin hora.
  final DateTime? date;

  /// Hora exacta mencionada.
  final DayTime? time;

  /// Franja del día mencionada ("en la tarde").
  final DayPeriod? dayPeriod;

  /// Momento absoluto ("en 20 minutos"). Tiene prioridad sobre fecha y hora.
  final DateTime? exactDue;

  /// "Antes de las 8": la hora es un límite y conviene avisar con margen.
  final bool isDeadline;

  /// Anticipación pedida explícitamente ("avísame 15 minutos antes").
  final Duration? leadTime;

  final Recurrence recurrence;

  /// `null` si no se mencionó (se usa la prioridad normal).
  final ReminderPriority? priority;
  final ReminderCategory category;

  /// La hora (7 a 11) se dijo sin "de la mañana/noche". Se guarda como de la
  /// mañana y se decide al resolver la fecha: "a las 8" dicho a las 10 a. m.
  /// para hoy es en la noche; para mañana, en la mañana.
  final bool ambiguousHour;

  bool get hasWhen =>
      exactDue != null || date != null || time != null || dayPeriod != null;

  bool get hasAnySlot =>
      hasWhen ||
      leadTime != null ||
      recurrence.repeats ||
      priority != null ||
      isDeadline;

  /// Hora efectiva: la exacta o la de la franja.
  DayTime? get effectiveTime => time ?? dayPeriod?.defaultTime;

  /// Fecha y hora del recordatorio, o `null` si falta información.
  DateTime? resolveDue(DateTime now) {
    if (exactDue != null) return exactDue;
    var t = effectiveTime;
    if (t == null) return null;
    if (ambiguousHour &&
        time != null &&
        !recurrence.repeats &&
        (date == null || date!.isSameDay(now))) {
      final morning = now.withTime(t.hour, t.minute);
      final evening = now.withTime(t.hour + 12, t.minute);
      if (!morning.isAfter(now) && evening.isAfter(now)) {
        t = DayTime(t.hour + 12, t.minute);
      }
    }
    if (date != null) return date!.withTime(t.hour, t.minute);

    // Sin fecha: la próxima vez que llegue esa hora, respetando la repetición.
    var candidate = now.withTime(t.hour, t.minute);
    if (!candidate.isAfter(now)) candidate = candidate.addDays(1);
    if (recurrence.frequency == RecurrenceFrequency.weekly &&
        recurrence.weekdays.isNotEmpty) {
      while (!recurrence.weekdays.contains(candidate.weekday)) {
        candidate = candidate.addDays(1);
      }
    } else if (recurrence.frequency == RecurrenceFrequency.weekdays) {
      while (candidate.weekday > DateTime.friday) {
        candidate = candidate.addDays(1);
      }
    }
    return candidate;
  }

  /// Datos que faltan, en el orden en que conviene preguntarlos.
  List<MissingSlot> missing(DateTime now) => [
    if (title.trim().isEmpty) MissingSlot.title,
    if (!hasWhen)
      MissingSlot.when
    else if (resolveDue(now) == null)
      MissingSlot.time,
  ];

  /// Aplica una corrección o respuesta: lo que la corrección menciona
  /// reemplaza a lo anterior; lo demás se conserva.
  ParsedReminder merge(ParsedReminder other) {
    final newWhenIsAbsolute = other.exactDue != null;
    final newDate = other.date;
    final newTime = other.time ?? (other.dayPeriod != null ? null : time);
    return ParsedReminder(
      title: other.title.trim().isNotEmpty ? other.title : title,
      exactDue: newWhenIsAbsolute
          ? other.exactDue
          : (other.date != null || other.time != null ? null : exactDue),
      date: newWhenIsAbsolute ? null : (newDate ?? date),
      time: newWhenIsAbsolute ? null : newTime,
      dayPeriod: newWhenIsAbsolute
          ? null
          : (other.dayPeriod ?? (other.time != null ? null : dayPeriod)),
      isDeadline: other.time != null || newWhenIsAbsolute
          ? other.isDeadline
          : isDeadline || other.isDeadline,
      leadTime: other.leadTime ?? leadTime,
      recurrence: other.recurrence.repeats ? other.recurrence : recurrence,
      priority: other.priority ?? priority,
      category: other.category != ReminderCategory.other
          ? other.category
          : category,
      ambiguousHour: other.time != null
          ? other.ambiguousHour
          : (other.dayPeriod == null && ambiguousHour),
    );
  }

  ParsedReminder copyWith({
    String? title,
    ReminderCategory? category,
    Duration? leadTime,
  }) => ParsedReminder(
    title: title ?? this.title,
    date: date,
    time: time,
    dayPeriod: dayPeriod,
    exactDue: exactDue,
    isDeadline: isDeadline,
    leadTime: leadTime ?? this.leadTime,
    recurrence: recurrence,
    priority: priority,
    category: category ?? this.category,
    ambiguousHour: ambiguousHour,
  );

  /// Reemplaza la franja ("en la tarde") por una hora concreta.
  ParsedReminder withPeriodResolvedTo(DayTime exact) => ParsedReminder(
    title: title,
    date: date,
    time: exact,
    exactDue: exactDue,
    isDeadline: isDeadline,
    leadTime: leadTime,
    recurrence: recurrence,
    priority: priority,
    category: category,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'date': date?.toIso8601String(),
    'time': time == null ? null : '${time!.hour}:${time!.minute}',
    'dayPeriod': dayPeriod?.name,
    'exactDue': exactDue?.toIso8601String(),
    'isDeadline': isDeadline,
    'leadTimeMinutes': leadTime?.inMinutes,
    'recurrence': recurrence.repeats ? recurrence.encode() : null,
    'priority': priority?.name,
    'category': category.name,
    'ambiguousHour': ambiguousHour,
  };

  @override
  bool operator ==(Object other) =>
      other is ParsedReminder &&
      other.title == title &&
      other.date == date &&
      other.time == time &&
      other.dayPeriod == dayPeriod &&
      other.exactDue == exactDue &&
      other.isDeadline == isDeadline &&
      other.leadTime == leadTime &&
      other.recurrence == recurrence &&
      other.priority == priority &&
      other.category == category &&
      other.ambiguousHour == ambiguousHour;

  @override
  int get hashCode => Object.hash(
    title,
    date,
    time,
    dayPeriod,
    exactDue,
    isDeadline,
    leadTime,
    recurrence,
    priority,
    category,
    ambiguousHour,
  );

  @override
  String toString() => 'ParsedReminder(${toJson()})';
}

/// Rango de días por el que pregunta el usuario ("¿qué tengo mañana?").
@immutable
class AgendaQuery {
  const AgendaQuery({
    required this.from,
    required this.to,
    this.isWeek = false,
  });

  final DateTime from;
  final DateTime to;
  final bool isWeek;
}

/// Resultado completo de interpretar una frase.
@immutable
class Interpretation {
  const Interpretation({
    required this.text,
    required this.intent,
    required this.confidence,
    required this.interpreterVersion,
    this.reminder = ParsedReminder.empty,
    this.agenda,
  });

  final String text;
  final VoiceIntent intent;
  final ParsedReminder reminder;
  final AgendaQuery? agenda;

  /// 0–1. Por debajo de ~0.6 conviene confirmar con más cuidado.
  final double confidence;

  /// Qué motor respondió (reglas o modelo) y su versión, para el dataset.
  final String interpreterVersion;
}
