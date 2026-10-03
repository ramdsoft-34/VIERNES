// Expresiones regulares armadas por partes.
// ignore_for_file: unnecessary_raw_strings

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_cancel_detector.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/ai/nlu/interpretation.dart';

enum ReplyKind {
  /// "Sí", "correcto", "guárdalo".
  affirm,

  /// "No" sin decir qué cambiar.
  deny,

  /// "Cancela", "olvídalo".
  cancel,

  /// "No, a las 9", "mejor el jueves".
  correction,

  /// No se entendió.
  unknown,
}

@immutable
class Reply {
  const Reply(this.kind, [this.correction]);

  final ReplyKind kind;

  /// Datos nuevos cuando [kind] es [ReplyKind.correction].
  final ParsedReminder? correction;
}

/// Entiende la respuesta del usuario cuando Viernes pregunta "¿lo guardo?".
class SpanishReplyParser {
  const SpanishReplyParser([
    this._interpreter = const SpanishRuleInterpreter(),
  ]);

  final SpanishRuleInterpreter _interpreter;

  static final _cancel = RegExp(
    r'^(?:no,?\s+)?(?:cancela(?:lo)?|cancelar|olvidalo|olvida(?:lo)? eso|'
    r'dejalo(?: asi)?|deja asi|no importa|nada|ninguno|salir|detente)\b',
  );
  static final _affirm = RegExp(
    r'^(?:si+|claro|correcto|exacto|dale|listo|ok|okay|okey|perfecto|'
    r'asi esta bien|esta bien|guardalo|guarda|de una|confirmo|confirmado|'
    r'afirmativo|eso es|bien|bueno|hagale|hagale pues|por supuesto|sip)\b',
  );
  static final _deny = RegExp(r'^(?:no+|nop|negativo|esta mal|incorrecto)\b');

  /// Palabras con las que se introduce una corrección.
  static final _correctionPrefix = RegExp(
    r'^[\s,.]*(?:(?:no+|si|pero|mejor|mas bien|perdon|corrijo|quise decir|'
    r'cambialo|cambia(?:lo)?\s+(?:a|para)|ponlo|ponlo\s+(?:a|para)|'
    r'no,?\s+(?:es|era)|es|era|seria|que sea)\b[\s,.]*)+',
  );

  Reply parse(String text, DateTime now) {
    final folded = SpanishText.fold(text).trim();
    if (folded.isEmpty) return const Reply(ReplyKind.unknown);
    if (_cancel.hasMatch(folded) || SpanishCancelDetector.isCancel(text)) {
      return const Reply(ReplyKind.cancel);
    }

    // Lo que viene después de "no," / "mejor" / "sí, pero"…
    final prefix = _correctionPrefix.firstMatch(folded);
    final rest = prefix == null ? text : text.substring(prefix.end);
    final parsed = _interpreter.parse(rest, now).reminder;

    // Solo cuentan como corrección fecha, hora, repetición o prioridad: un
    // texto suelto ("sí, guárdalo") no debe cambiar el título. Para cambiar
    // el título, Viernes pregunta "¿Qué quieres cambiar?".
    if (parsed.hasAnySlot) {
      return Reply(ReplyKind.correction, parsed.copyWith(title: ''));
    }
    if (_affirm.hasMatch(folded)) return const Reply(ReplyKind.affirm);
    if (_deny.hasMatch(folded)) return const Reply(ReplyKind.deny);
    return const Reply(ReplyKind.unknown);
  }
}
