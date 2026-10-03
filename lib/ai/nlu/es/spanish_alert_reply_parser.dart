// Expresiones regulares armadas por partes.
// ignore_for_file: unnecessary_raw_strings

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';

enum AlertReplyKind {
  /// "Sí, ya lo hice".
  done,

  /// "Todavía no", "en 20 minutos".
  snooze,
  unknown,
}

@immutable
class AlertReply {
  const AlertReply(this.kind, {this.until});

  final AlertReplyKind kind;

  /// Hasta cuándo posponer, si el usuario lo dijo. Si es `null`, se usa la
  /// duración de los ajustes.
  final DateTime? until;
}

/// Entiende la respuesta a la alerta "¿Ya lo hiciste?".
class SpanishAlertReplyParser {
  const SpanishAlertReplyParser([
    this._interpreter = const SpanishRuleInterpreter(),
  ]);

  final SpanishRuleInterpreter _interpreter;

  static final _notYet = RegExp(
    r'^(?:no+\b|todavia no|aun no|despues|mas tarde|luego|ahorita no|'
    r'ahora no|en un momento|recuerdamelo|recordarme|avisame)',
  );
  static final _done = RegExp(
    r'^(?:si+\b|ya\b|listo|hecho|lo hice|ya lo hice|ya esta|terminado|'
    r'termine|completado|claro|por supuesto|sip)|\bya lo hice\b',
  );

  AlertReply parse(String text, DateTime now) {
    final folded = SpanishText.fold(text).trim();
    if (folded.isEmpty) return const AlertReply(AlertReplyKind.unknown);

    // "Todavía no, en 20 minutos" / "a las 5": pospone hasta ese momento.
    final parsed = _interpreter.parse(text, now).reminder;
    final until = parsed.resolveDue(now);
    if (until != null && until.isAfter(now)) {
      return AlertReply(AlertReplyKind.snooze, until: until);
    }
    if (_notYet.hasMatch(folded)) {
      return const AlertReply(AlertReplyKind.snooze);
    }
    if (_done.hasMatch(folded)) return const AlertReply(AlertReplyKind.done);
    return const AlertReply(AlertReplyKind.unknown);
  }
}
