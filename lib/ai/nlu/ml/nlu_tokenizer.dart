import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';

/// Palabra normalizada con su posición en el texto original.
@immutable
class NluToken {
  const NluToken(this.text, this.start, this.end);

  final String text;
  final int start;
  final int end;
}

/// Tokenizador del intérprete neuronal. Debe coincidir exactamente con el de
/// entrenamiento (`training/nlu/nlu_data.py`): minúsculas sin tildes y
/// secuencias de letras y dígitos.
abstract final class NluTokenizer {
  static final _token = RegExp('[a-z0-9]+');
  static const num = '<num>';

  static List<NluToken> tokenize(String text) {
    // `fold` conserva la longitud: las posiciones sirven en el original.
    final folded = SpanishText.fold(text);
    return [
      for (final m in _token.allMatches(folded))
        NluToken(m[0]!, m.start, m.end),
    ];
  }

  static String normalize(String token) =>
      RegExp(r'^\d+$').hasMatch(token) ? num : token;

  /// FNV-1a de 32 bits sobre UTF-8 (palabras fuera del vocabulario).
  static int fnv1a(String token) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(token)) {
      hash ^= byte;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash;
  }
}
