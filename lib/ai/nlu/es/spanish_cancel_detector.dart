// Expresiones regulares armadas por partes.
// ignore_for_file: unnecessary_raw_strings

import 'package:viernes/ai/nlu/es/spanish_text.dart';

/// Reconoce cuando el usuario quiere dejar la conversación: se activó por
/// error, cambió de idea o ya no necesita lo que iba a pedir.
///
/// Solo cuenta si la frase completa es una cancelación ("ya no lo
/// necesito", "olvídalo, gracias"). Así "recuérdame que ya no quiero
/// café" sigue siendo un recordatorio.
abstract final class SpanishCancelDetector {
  /// Una muletilla al inicio que no cambia el sentido.
  static final _leading = RegExp(
    r'(?:viernes|oye|eh+|ah+|mm+|ay|uy|ups|ush|perdon|disculpa|'
    r'lo siento|no+|bueno|ok|okay|listo|ya|mejor|entonces|pues)\b',
  );

  /// Cortesías al final.
  static final _trailing = RegExp(
    r'(?:[\s,.]*\b(?:gracias|muchas gracias|por favor|viernes|mejor|'
    r'entonces|pues|ya|por ahora|de momento|todo bien|tranquila?|'
    r'mas bien|asi)\b)+$',
  );

  static final _phrases = RegExp(
    '^(?:${[
      // Cancelar explícito.
      r'cancela(?:lo|la|r)?(?: eso| todo| el recordatorio| la orden)?',
      r'olvida(?:lo|la|te)?(?: eso| todo)?',
      r'deja(?:lo|la)?(?: asi| eso| quieto| ahi)?',
      r'no importa',
      r'no(?: muchas)? gracias',
      r'nada(?: nada)?',
      r'ninguno|ninguna',
      r'sal(?:ir|te)?|cierra(?:r)?|termina(?:r)?|detente|para|basta|stop',
      r'chao|adios|hasta luego',
      // Ya no lo necesita.
      r'(?:ya )?no (?:lo |la )?(?:quiero|necesito)(?: nada| eso| nada mas)?',
      r'(?:ya )?no necesito nada(?: mas)?',
      r'(?:ya )?no (?:hace falta|es necesario|importa|se necesita)',
      r'ya no',
      r'ya no (?:quiero que me (?:lo )?recuerdes|me lo recuerdes)',
      r'no quiero (?:que me (?:lo )?recuerdes )?nada',
      r'en otro momento|despues te digo|luego te (?:digo|aviso)',
      r'ahora no|mejor no|mejor nada|asi no',
      // Activación por error.
      r'me equivoque|fue (?:un error|sin querer|por error)|sin querer',
      r'te (?:llame|active) (?:sin querer|por error)',
      r'no te (?:llame|estaba hablando(?: a ti)?|hable)',
      r'no (?:era|es) (?:nada|contigo|para ti|a ti)',
      r'falsa alarma',
      r'no estaba hablando contigo',
    ].join('|')})\$',
  );

  static bool isCancel(String text) {
    var folded = SpanishText.fold(text)
        .replaceAll(RegExp(r'[¡!¿?.,;:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (folded.isEmpty) return false;
    if (_phrases.hasMatch(folded)) return true;
    folded = folded.replaceFirst(_trailing, '').trim();
    // Quita muletillas del inicio de a una, probando en cada paso: en
    // "ya no lo necesito" el "ya no" es parte de la frase. "No" o "ya"
    // solos no son cancelación (son respuestas a la pregunta).
    var rest = folded;
    while (rest.isNotEmpty) {
      if (_phrases.hasMatch(rest)) return true;
      final filler = _leading.matchAsPrefix(rest);
      if (filler == null) return false;
      rest = rest.substring(filler.end).trim();
    }
    return false;
  }
}
