import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';

/// «Dos días antes del cumpleaños de Sofi» → 2 días antes de ese evento.
@immutable
class RelativeEventRequest {
  const RelativeEventRequest({
    required this.offset,
    required this.eventText,
    required this.task,
  });

  /// Cuánto antes del evento.
  final Duration offset;

  /// Cómo nombró el evento («el cumpleaños de Sofi»).
  final String eventText;

  /// Lo que hay que hacer, si lo dijo («comprar el regalo»); vacío si solo
  /// pidió el aviso.
  final String task;
}

/// Entiende pedidos relativos a otro recordatorio y los resuelve contra la
/// agenda del usuario.
abstract final class SpanishRelativeEvent {
  static final _pattern = RegExp(
    r'(?:,\s*)?(?:con\s+)?(un|una|media|medio|\d+|[a-z]+)\s+'
    r'(minutos?|horas?|dias?|semanas?|mes|meses)\s+'
    r'(?:de\s+anticipacion\s+|antes\s+)(?:a|de|del|al|para)\s+'
    r'(?:(?:el|la|los|las|mi|su)\s+)?(.+)$',
  );

  /// «Avísame» sin tarea: solo quiere el aviso previo.
  static final _notifyOnly = RegExp(
    r'^(?:av[ií]same|recu[eé]rdamelo|recu[eé]rdame)\s*$',
    caseSensitive: false,
  );

  /// Palabras que no ayudan a reconocer el evento.
  static const _stop = {
    'el',
    'la',
    'los',
    'las',
    'de',
    'del',
    'a',
    'al',
    'mi',
    'su',
    'mis',
    'que',
    'y',
    'en',
    'para',
    'con',
    'un',
    'una',
  };

  static RelativeEventRequest? parse(String input) {
    final text = input.trim();
    final folded = SpanishText.fold(text);
    final m = _pattern.firstMatch(folded);
    if (m == null) return null;
    final amount = switch (m[1]!) {
      'un' || 'una' => 1.0,
      'media' || 'medio' => 0.5,
      final raw => SpanishText.parseNumber(raw)?.toDouble(),
    };
    if (amount == null || amount <= 0) return null;
    final unit = m[2]!;
    final minutes = switch (unit) {
      _ when unit.startsWith('minuto') => 1,
      _ when unit.startsWith('hora') => 60,
      _ when unit.startsWith('dia') => 60 * 24,
      _ when unit.startsWith('semana') => 60 * 24 * 7,
      _ => 60 * 24 * 30,
    };
    // El evento llega hasta el final; `fold` conserva las posiciones.
    final eventText = text.substring(m.end - m[3]!.length, m.end).trim();
    final before = text.substring(0, m.start).trim();
    return RelativeEventRequest(
      offset: Duration(minutes: (amount * minutes).round()),
      eventText: eventText.replaceAll(RegExp(r'[.?!¡¿]+$'), ''),
      task: SpanishRuleInterpreter.cleanTitle(
        before.replaceFirst(_notifyOnly, ''),
      ),
    );
  }

  /// El recordatorio futuro que mejor coincide con [eventText], o nulo si
  /// ninguno se parece lo suficiente.
  static Reminder? findEvent(
    String eventText,
    Iterable<Reminder> reminders,
    DateTime now,
  ) {
    final wanted = _words(eventText);
    if (wanted.isEmpty) return null;
    Reminder? best;
    var bestScore = 0.0;
    for (final r in reminders) {
      if (!r.dueAt.isAfter(now)) continue;
      final have = _words(r.title);
      if (have.isEmpty) continue;
      final common = wanted.intersection(have).length;
      final score = common / wanted.length;
      if (score > bestScore ||
          (score == bestScore &&
              best != null &&
              r.dueAt.isBefore(best.dueAt))) {
        bestScore = score;
        best = r;
      }
    }
    return bestScore >= 0.6 ? best : null;
  }

  static Set<String> _words(String text) => {
    for (final w in SpanishText.fold(text).split(RegExp('[^a-z0-9]+')))
      if (w.isNotEmpty && !_stop.contains(w)) w,
  };
}
